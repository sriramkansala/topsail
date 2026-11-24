import AppKit
import Combine
import Security

/// Updates the direct download from its GitHub releases. What's downloaded is trusted only for
/// its signature: it must be Topsail, signed with a Developer ID of the same team as the copy
/// that's running, notarized by Apple, and a newer version. A copy that isn't itself signed that
/// way (a development build) never updates. The App Store updates its own build.
@MainActor
final class Updater: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case downloading(String)
        /// Verified; installed when Topsail quits, or with "Restart to Update".
        case ready(String)
        case failed(String)
        case developmentBuild
    }

    @Published private(set) var state: State = .idle

    nonisolated static let repository = "sriramkansala/topsail"
    nonisolated static let identifier = "app.topsail.Topsail.direct"

    #if DIRECT
    private var staged: URL?
    private var timer: Timer?
    private var task: Task<Void, Never>?

    func start() {
        guard timer == nil else { return }
        check()
        let timer = Timer(timeInterval: 24 * 3600, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        task?.cancel()
        discard()
        state = .idle
    }

    func check() {
        if case .ready = state { return }
        guard task == nil else { return }
        guard let team = Self.ownTeam() else {
            state = .developmentBuild
            return
        }
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        state = .checking
        task = Task {
            defer { task = nil }
            do {
                guard let release = try await Self.latestRelease(newerThan: current) else {
                    state = .upToDate
                    return
                }
                state = .downloading(release.version)
                let app = try await Self.download(release, team: team, current: current)
                guard !Task.isCancelled else {
                    try? FileManager.default.removeItem(at: app.deletingLastPathComponent())
                    return
                }
                staged = app
                state = .ready(release.version)
            } catch is CancellationError {
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    /// Replaces this copy with the verified one (on quitting), checking it once more first.
    @discardableResult
    func installIfReady() -> Bool {
        guard let staged, let team = Self.ownTeam() else { return false }
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        do {
            try Self.verify(staged, team: team, newerThan: current)
            _ = try FileManager.default.replaceItemAt(Bundle.main.bundleURL, withItemAt: staged)
            discard()
            return true
        } catch {
            state = .failed(error.localizedDescription)
            discard()
            return false
        }
    }

    func restartToUpdate() {
        let path = Bundle.main.bundlePath
        guard installIfReady() else { return }
        // Waits for this copy to quit, then opens the new one. Passed as arguments, not as script.
        let relaunch = Process()
        relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
        relaunch.arguments = ["-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$2\"", "sh",
                              String(ProcessInfo.processInfo.processIdentifier), path]
        try? relaunch.run()
        NSApp.terminate(nil)
    }

    private func discard() {
        if let staged { try? FileManager.default.removeItem(at: staged.deletingLastPathComponent()) }
        staged = nil
    }
    #else
    func start() {}
    func stop() {}
    func check() {}
    func installIfReady() {}
    func restartToUpdate() {}
    #endif
}

#if DIRECT
extension Updater {
    struct Release: Equatable {
        let version: String
        let url: URL
    }

    enum Problem: LocalizedError, Equatable {
        case server
        case unpack
        case signature
        case notNewer

        var errorDescription: String? {
            switch self {
            case .server: return String(localized: "Couldn't reach GitHub.")
            case .unpack: return String(localized: "The download couldn't be opened.")
            case .signature: return String(localized: "The download isn't signed by Topsail's developer, so it wasn't installed.")
            case .notNewer: return String(localized: "The download isn't a newer version, so it wasn't installed.")
            }
        }
    }

    nonisolated static func latestRelease(newerThan current: String) async throws -> Release? {
        guard let url = URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=10") else { throw Problem.server }
        let (data, response) = try await URLSession(configuration: .ephemeral).data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Problem.server }
        return newest(in: data, newerThan: current)
    }

    /// The newest published release with a zip of this repository's own, if newer than `current`.
    nonisolated static func newest(in data: Data, newerThan current: String) -> Release? {
        guard let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] else { return nil }
        return list.compactMap { release -> Release? in
            guard release["draft"] as? Bool == false, release["prerelease"] as? Bool == false,
                  let tag = release["tag_name"] as? String, let version = normalized(tag),
                  isNewer(version, than: current), let assets = release["assets"] as? [[String: Any]] else { return nil }
            let url = assets.lazy.compactMap { ($0["browser_download_url"] as? String).flatMap(URL.init(string:)) }
                .first(where: isOwnDownload)
            return url.map { Release(version: version, url: $0) }
        }
        .max { isNewer($1.version, than: $0.version) }
    }

    nonisolated static func isOwnDownload(_ url: URL) -> Bool {
        url.scheme == "https" && url.host() == "github.com" && url.user() == nil && url.port == nil
            && url.path().hasPrefix("/\(repository)/releases/download/") && !url.path().contains("..")
            && url.pathExtension.lowercased() == "zip"
    }

    /// "v1.2.3" or "1.2" as numbers joined by dots; nil for anything else.
    nonisolated static func normalized(_ tag: String) -> String? {
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard (1...4).contains(parts.count), parts.allSatisfy({ !$0.isEmpty && $0.count <= 6 && $0.allSatisfy(\.isASCII) && Int($0) != nil && !$0.hasPrefix("-") && !$0.hasPrefix("+") }) else { return nil }
        return version
    }

    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        guard let a = normalized(a)?.split(separator: ".").compactMap({ Int($0) }),
              let b = normalized(b)?.split(separator: ".").compactMap({ Int($0) }) else { return false }
        for index in 0..<max(a.count, b.count) {
            let x = index < a.count ? a[index] : 0, y = index < b.count ? b[index] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Downloads, unpacks and verifies; returns the app, in a private folder of its own.
    nonisolated static func download(_ release: Release, team: String, current: String) async throws -> URL {
        let (file, response) = try await URLSession(configuration: .ephemeral).download(from: release.url)
        defer { try? FileManager.default.removeItem(at: file) }
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Problem.server }
        // On the app's own volume, so putting it in place is a rename.
        let folder = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                 appropriateFor: Bundle.main.bundleURL, create: true)
        do {
            let unpack = Process()
            unpack.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unpack.arguments = ["-x", "-k", file.path, folder.path]
            try unpack.run()
            unpack.waitUntilExit()
            let app = folder.appendingPathComponent("Topsail.app")
            guard unpack.terminationStatus == 0, FileManager.default.fileExists(atPath: app.path) else { throw Problem.unpack }
            try verify(app, team: team, newerThan: current)
            return app
        } catch {
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    /// Developer ID, this team, notarized, this app.
    nonisolated static func requirement(team: String) -> String {
        """
        anchor apple generic and identifier "\(identifier)" \
        and certificate 1[field.1.2.840.113635.100.6.2.6] exists \
        and certificate leaf[field.1.2.840.113635.100.6.1.13] exists \
        and certificate leaf[subject.OU] = "\(team)" and notarized
        """
    }

    nonisolated static func verify(_ app: URL, team: String, newerThan current: String) throws {
        // A team identifier is ten letters and digits; nothing else goes into the requirement.
        guard team.count == 10, team.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }) else { throw Problem.signature }
        let values = try? app.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey])
        guard values?.isSymbolicLink == false, values?.isDirectory == true else { throw Problem.signature }
        var code: SecStaticCode?
        var compiled: SecRequirement?
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode | kSecCSStrictValidate
                               | kSecCSRestrictSymlinks)
        guard SecStaticCodeCreateWithPath(app as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(requirement(team: team) as CFString, [], &compiled) == errSecSuccess, let compiled,
              SecStaticCodeCheckValidity(code, flags, compiled) == errSecSuccess else { throw Problem.signature }
        // Read from the signed Info.plist.
        guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              let version = info["CFBundleShortVersionString"] as? String,
              isNewer(version, than: current) else { throw Problem.notNewer }
    }

    /// The running copy's team, if it's a Developer ID build of Topsail; nil for any other.
    nonisolated static func ownTeam() -> String? {
        var code: SecCode?
        var staticCode: SecStaticCode?
        var info: CFDictionary?
        guard SecCodeCopySelf([], &code) == errSecSuccess, let code,
              SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
              SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let team = (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String else { return nil }
        var compiled: SecRequirement?
        guard SecRequirementCreateWithString("""
            anchor apple generic and identifier "\(identifier)" \
            and certificate 1[field.1.2.840.113635.100.6.2.6] exists \
            and certificate leaf[field.1.2.840.113635.100.6.1.13] exists
            """ as CFString, [], &compiled) == errSecSuccess, let compiled,
              SecStaticCodeCheckValidity(staticCode, [], compiled) == errSecSuccess else { return nil }
        return team
    }
}
#endif
