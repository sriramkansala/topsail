// Films continuity cells on the real screen and cuts filmstrips from the film.
//
//   film record --pid <topsail pid> --out <film.mov>
//       Records Topsail's own notch window with ScreenCaptureKit at 60 fps until that process
//       quits. Only that window is captured (over plain grey), so nothing else on the screen,
//       and nothing personal, is in the film. Writes <film.mov> and <film.mov>.json (the clock).
//   film strips --film <film.mov> --traces <folder> --cells a,b,c --out <folder> --label before
//       For each cell, a PNG with two rows: every frame for the first quarter second after the
//       cell's first trigger, and the whole cell at even steps. Times come from the cell's trace.
//
// Built and run by scripts/continuity.sh (`--film`). Needs Screen Recording permission for the
// terminal it runs from.
import AppKit
import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

func argument(_ name: String) -> String? {
    let arguments = CommandLine.arguments
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    return arguments[index + 1]
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
    exit(1)
}

/// The part of the notch window that is filmed: its top, where the island is, in points.
let filmedSize = CGSize(width: 700, height: 480)
let filmScale: CGFloat = 2

// MARK: - Recording

final class Recorder: NSObject, SCStreamOutput, SCStreamDelegate {
    private let writer: AVAssetWriter
    private let input: AVAssetWriterInput
    private let url: URL
    private var firstTime: CMTime?
    private var frames = 0
    private let queue = DispatchQueue(label: "film")

    init(url: URL) throws {
        self.url = url
        try? FileManager.default.removeItem(at: url)
        writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(filmedSize.width * filmScale),
            AVVideoHeightKey: Int(filmedSize.height * filmScale),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 24_000_000,
                                              AVVideoMaxKeyFrameIntervalKey: 30],
        ])
        input.expectsMediaDataInRealTime = true
        writer.add(input)
    }

    func start(window: SCWindow) async throws -> SCStream {
        let configuration = SCStreamConfiguration()
        configuration.sourceRect = CGRect(origin: .zero, size: filmedSize)
        configuration.width = Int(filmedSize.width * filmScale)
        configuration.height = Int(filmedSize.height * filmScale)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        configuration.backgroundColor = CGColor(gray: 0.42, alpha: 1)
        configuration.queueDepth = 8
        let stream = SCStream(filter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration,
                              delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
        return stream
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let raw = attachments.first?[.status] as? Int, SCFrameStatus(rawValue: raw) == .complete else { return }
        let time = buffer.presentationTimeStamp
        if firstTime == nil {
            firstTime = time
            writer.startWriting()
            writer.startSession(atSourceTime: time)
        }
        if input.isReadyForMoreMediaData, input.append(buffer) { frames += 1 }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        FileHandle.standardError.write("The film stopped: \(error.localizedDescription)\n".data(using: .utf8)!)
    }

    func finish() async {
        queue.sync {}
        guard let firstTime else { fail("No frames were filmed (is Screen Recording allowed for this terminal?)") }
        input.markAsFinished()
        await writer.finishWriting()
        let clock: [String: Any] = ["start": firstTime.seconds, "frames": frames]
        try? JSONSerialization.data(withJSONObject: clock).write(to: URL(fileURLWithPath: url.path + ".json"))
        print("Filmed \(frames) frames into \(url.lastPathComponent)")
    }
}

func record() async {
    guard let pidText = argument("--pid"), let pid = Int32(pidText), let out = argument("--out") else {
        fail("film record --pid <pid> --out <film.mov>")
    }
    var window: SCWindow?
    for _ in 0..<40 where window == nil {
        let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        window = content?.windows
            .filter { $0.owningApplication?.processID == pid && $0.frame.width >= 600 }
            .max { $0.frame.height < $1.frame.height }
        if window == nil { try? await Task.sleep(for: .milliseconds(250)) }
    }
    guard let window else { fail("Topsail's notch window was not found (pid \(pid)).") }
    do {
        let recorder = try Recorder(url: URL(fileURLWithPath: out))
        let stream = try await recorder.start(window: window)
        while kill(pid, 0) == 0 { try? await Task.sleep(for: .milliseconds(200)) }
        try? await stream.stopCapture()
        await recorder.finish()
    } catch {
        fail("Could not film: \(error.localizedDescription)")
    }
}

// MARK: - Filmstrips

struct CellTrace {
    let id: String
    let summary: String
    let start: String
    /// Host-clock seconds when the trace began.
    let clock: Double
    let length: Double
    let steps: [(at: Double, label: String)]
    /// The island's largest size during the cell, in points.
    let reach: CGSize

    init?(url: URL) {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let lines = text.split(separator: "\n")
        guard lines.count > 2,
              let header = try? JSONSerialization.jsonObject(with: Data(lines[0].utf8)) as? [String: Any] else { return nil }
        id = header["cell"] as? String ?? ""
        summary = header["summary"] as? String ?? ""
        start = header["start"] as? String ?? ""
        steps = (header["steps"] as? [[Any]] ?? []).compactMap { step in
            guard let at = step.first as? Double, let label = step.last as? String else { return nil }
            return (at, label)
        }
        var clock: Double?
        var width: CGFloat = 0, height: CGFloat = 0, last = 0.0
        for line in lines.dropFirst() {
            guard let frame = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else { continue }
            if clock == nil, let value = frame["clock"] as? Double { clock = value }
            last = frame["t"] as? Double ?? last
            if let island = frame["i"] as? [Double] {
                width = max(width, island[0])
                height = max(height, island[1])
            }
            for entries in (frame["e"] as? [String: [[Double]]] ?? [:]).values {
                for entry in entries where entry[5] > 0.05 { height = max(height, min(entry[2] + entry[4], 470)) }
            }
        }
        guard let clock else { return nil }
        self.clock = clock
        length = last
        reach = CGSize(width: width, height: height)
    }
}

func strips() async {
    guard let film = argument("--film"), let traces = argument("--traces"), let cells = argument("--cells"),
          let out = argument("--out") else {
        fail("film strips --film <film.mov> --traces <folder> --cells a,b --out <folder> [--label before]")
    }
    let label = argument("--label") ?? "run"
    guard let clockData = try? Data(contentsOf: URL(fileURLWithPath: film + ".json")),
          let clock = try? JSONSerialization.jsonObject(with: clockData) as? [String: Any],
          let filmStart = clock["start"] as? Double else { fail("No clock beside \(film).") }
    let asset = AVURLAsset(url: URL(fileURLWithPath: film))
    let generator = AVAssetImageGenerator(asset: asset)
    generator.requestedTimeToleranceBefore = .zero
    generator.requestedTimeToleranceAfter = .zero
    try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

    for id in cells.split(separator: ",").map(String.init) {
        guard let trace = CellTrace(url: URL(fileURLWithPath: traces).appendingPathComponent(id + ".jsonl")) else {
            print("No trace with a clock for \(id); skipped.")
            continue
        }
        func image(at milliseconds: Double) async -> CGImage? {
            let seconds = trace.clock + milliseconds / 1000 - filmStart
            guard seconds >= 0 else { return nil }
            return try? await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 6000)).image
        }
        let trigger = trace.steps.first?.at ?? 250
        // Row 1: every frame (60 fps) from just before the first trigger. Row 2: the whole cell.
        let close = (0..<16).map { trigger - 16.7 + Double($0) * 1000 / 60 }
        let whole = (0..<16).map { trace.length * Double($0) / 15 }
        var rows: [[(time: Double, image: CGImage)]] = []
        for times in [close, whole] {
            var row: [(Double, CGImage)] = []
            for time in times {
                if let frame = await image(at: min(time, trace.length)) { row.append((time, frame)) }
            }
            rows.append(row)
        }
        guard rows.allSatisfy({ !$0.isEmpty }) else {
            print("The film has no frames for \(id); skipped.")
            continue
        }
        let url = URL(fileURLWithPath: out).appendingPathComponent("\(id).\(label).png")
        compose(trace: trace, rows: rows, titles: ["Every frame from the first trigger (60 fps)", "The whole cell"],
                label: label, to: url)
        print("Wrote \(url.lastPathComponent)")
    }
}

func compose(trace: CellTrace, rows: [[(time: Double, image: CGImage)]], titles: [String], label: String, to url: URL) {
    // Each frame is cropped to the island's reach, centred on the notch.
    let crop = CGSize(width: min(filmedSize.width, trace.reach.width + 44), height: min(filmedSize.height, trace.reach.height + 26))
    let shown: CGFloat = min(1, 300 / crop.width)   // points on the strip per point on screen
    let cell = CGSize(width: (crop.width * shown).rounded(), height: (crop.height * shown).rounded())
    let columns = 8
    let gap: CGFloat = 6, margin: CGFloat = 16, caption: CGFloat = 14, heading: CGFloat = 54, rowTitle: CGFloat = 22
    let rowsOfCells = rows.map { ($0.count + columns - 1) / columns }
    let width = margin * 2 + CGFloat(columns) * cell.width + CGFloat(columns - 1) * gap
    var height = margin + heading
    for count in rowsOfCells { height += rowTitle + CGFloat(count) * (cell.height + caption + gap) }
    height += margin - gap

    let scale: CGFloat = 2
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                                        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return }
    bitmap.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    NSColor(white: 0.13, alpha: 1).setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()

    func draw(_ text: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .white) {
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight),
                                                         .foregroundColor: color]
        // Flipped layout: y is measured from the top.
        NSAttributedString(string: text, attributes: attributes)
            .draw(at: CGPoint(x: point.x, y: height - point.y - size * 1.25))
    }

    draw("\(trace.id)  ·  \(label)", at: CGPoint(x: margin, y: margin), size: 14, weight: .semibold)
    let steps = trace.steps.map { "\(Int($0.at)) ms \($0.label)" }.joined(separator: "  →  ")
    draw("\(trace.start)   |   \(steps)", at: CGPoint(x: margin, y: margin + 22), size: 10.5, color: NSColor(white: 0.7, alpha: 1))

    var y = margin + heading
    for (index, row) in rows.enumerated() {
        draw(titles[index], at: CGPoint(x: margin, y: y), size: 10.5, weight: .medium, color: NSColor(white: 0.82, alpha: 1))
        y += rowTitle
        for (position, frame) in row.enumerated() {
            let column = position % columns
            if position > 0, column == 0 { y += cell.height + caption + gap }
            let x = margin + CGFloat(column) * (cell.width + gap)
            let pixels = CGRect(x: (filmedSize.width - crop.width) / 2 * filmScale, y: 0,
                                width: crop.width * filmScale, height: crop.height * filmScale)
            if let cropped = frame.image.cropping(to: pixels) {
                context.cgContext.interpolationQuality = .high
                context.cgContext.draw(cropped, in: CGRect(x: x, y: height - y - cell.height, width: cell.width, height: cell.height))
            }
            draw("\(Int(frame.time.rounded())) ms", at: CGPoint(x: x, y: y + cell.height + 1), size: 9,
                 color: NSColor(white: 0.62, alpha: 1))
        }
        y += cell.height + caption + gap
    }
    NSGraphicsContext.restoreGraphicsState()
    try? bitmap.representation(using: .png, properties: [:])?.write(to: url)
}

// MARK: - Main

let mode = CommandLine.arguments.dropFirst().first ?? ""
Task {
    switch mode {
    case "record": await record()
    case "strips": await strips()
    default: fail("film record … | film strips …  (see the top of scripts/continuity/film.swift)")
    }
    exit(0)
}
RunLoop.main.run()
