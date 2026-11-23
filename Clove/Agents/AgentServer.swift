#if DIRECT
import Darwin
import Foundation

/// A tiny HTTP server on a Unix socket in `~/.clove` (readable and writable by the user alone),
/// where the agents' hooks post their events (`POST /<agent>/<event>`, JSON body) and wait for
/// Clove's answer in the response. One request per connection.
final class AgentServer: @unchecked Sendable {
    /// Answers one event: the response body (empty for "no opinion").
    typealias Handler = @Sendable (_ agent: String, _ event: String, _ body: Data) async -> Data

    let socketPath: String
    private let handler: Handler
    private var listener: Int32 = -1
    private var source: DispatchSourceRead?
    private let queue = DispatchQueue(label: "app.clove.agents", qos: .userInitiated, attributes: .concurrent)
    /// The largest event accepted (agents send tool inputs, which can carry whole files).
    private let maxBody = 8 * 1024 * 1024

    init(socketPath: String, handler: @escaping Handler) {
        self.socketPath = socketPath
        self.handler = handler
    }

    func start() throws {
        stop()
        let folder = (socketPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        unlink(socketPath)

        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(.init(rawValue: errno) ?? .EIO) }
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(socketPath.utf8)
        guard pathBytes.count < MemoryLayout.size(ofValue: address.sun_path) else {
            close(fd)
            throw POSIXError(.ENAMETOOLONG)
        }
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            raw.copyBytes(from: pathBytes)
            raw[pathBytes.count] = 0
        }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, listen(fd, 16) == 0 else {
            let error = POSIXError(.init(rawValue: errno) ?? .EIO)
            close(fd)
            throw error
        }
        chmod(socketPath, 0o600)
        listener = fd

        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let client = accept(fd, nil, nil)
            if client >= 0 { self.serve(client) }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        self.source = source
    }

    func stop() {
        source?.cancel()
        source = nil
        listener = -1
        unlink(socketPath)
    }

    private func serve(_ client: Int32) {
        var on: Int32 = 1
        setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size))
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        guard let (agent, event, body) = readRequest(client) else {
            respond(client, status: "400 Bad Request", body: Data())
            return
        }
        Task {
            let answer = await handler(agent, event, body)
            respond(client, status: "200 OK", body: answer)
        }
    }

    /// Reads "POST /agent/event HTTP/1.1", the headers and a Content-Length body.
    private func readRequest(_ client: Int32) -> (String, String, Data)? {
        var buffer = Data()
        var chunk = [UInt8](repeating: 0, count: 16 * 1024)
        let separator = Data("\r\n\r\n".utf8)
        var headerEnd: Range<Data.Index>?
        while headerEnd == nil {
            let count = read(client, &chunk, chunk.count)
            guard count > 0 else { return nil }
            buffer.append(contentsOf: chunk[0..<count])
            headerEnd = buffer.range(of: separator)
            if buffer.count > 64 * 1024, headerEnd == nil { return nil }
        }
        guard let headerEnd,
              let head = String(data: buffer[..<headerEnd.lowerBound], encoding: .utf8) else { return nil }
        let lines = head.components(separatedBy: "\r\n")
        let requestLine = lines.first?.split(separator: " ") ?? []
        guard requestLine.count >= 2 else { return nil }
        let parts = requestLine[1].split(separator: "/").map(String.init)
        guard parts.count >= 2 else { return nil }

        let length = lines.dropFirst().compactMap { line -> Int? in
            let pair = line.split(separator: ":", maxSplits: 1)
            guard pair.count == 2, pair[0].lowercased() == "content-length" else { return nil }
            return Int(pair[1].trimmingCharacters(in: .whitespaces))
        }.first ?? 0
        guard length <= maxBody else { return nil }

        var body = Data(buffer[headerEnd.upperBound...])
        while body.count < length {
            let count = read(client, &chunk, min(chunk.count, length - body.count))
            guard count > 0 else { return nil }
            body.append(contentsOf: chunk[0..<count])
        }
        return (parts[0], parts[1], body)
    }

    private func respond(_ client: Int32, status: String, body: Data) {
        var response = Data("HTTP/1.1 \(status)\r\nContent-Type: application/json\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
        response.append(body)
        response.withUnsafeBytes { raw in
            var offset = 0
            while offset < raw.count {
                let written = write(client, raw.baseAddress! + offset, raw.count - offset)
                if written <= 0 { break }
                offset += written
            }
        }
        close(client)
    }
}
#endif
