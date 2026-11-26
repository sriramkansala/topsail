import AVFoundation
import ScreenCaptureKit

/// One recording's capture, through ScreenCaptureKit.
///
/// The screen: `SCStream` with an `SCRecordingOutput`, which writes the movie (video, the Mac's
/// sound and the microphone). Pausing ends the current piece and resuming starts a new one; the
/// pieces are joined when the recording stops (`RecordingFiles.join`).
///
/// A call: the same stream reduced to a 2 × 2 picture once a second, whose sound (the Mac's, the
/// other side) and microphone (you) go to an `AudioFileWriter`, one track each.
///
/// Either way, both sounds are measured as they arrive, for the island's level meters.
@MainActor
final class CaptureSession: NSObject {
    struct Options {
        var kind: RecordingKind
        /// 0 = the main display.
        var displayID: CGDirectDisplayID
        var microphone: Bool
        var systemAudio: Bool
        var separateTracks: Bool
        var format: RecorderSettings.Format
        /// Leave the island in the picture.
        var showsIsland: Bool
    }

    let options: Options
    /// Where this recording's pieces are written until it's saved.
    let directory: URL
    /// Levels (the Mac's sound, the microphone; 0...1), about twelve times a second.
    var onLevels: ((Float, Float) -> Void)?
    /// The stream stopped by itself: the user stopped sharing from the menu bar, or the display went
    /// away. What was captured is still there for `stop()`.
    var onInterrupted: ((Error) -> Void)?

    private let queue = DispatchQueue(label: "app.topsail.recorder.capture", qos: .userInitiated)
    /// Touched only on `queue`.
    private nonisolated let onQueue = QueueState()
    private var stream: SCStream?
    /// The piece being recorded now; nil while paused.
    private var recordingOutput: SCRecordingOutput?
    /// Every piece, in the order recorded, and those whose files haven't closed yet.
    private var pieceOrder: [(id: ObjectIdentifier, url: URL)] = []
    private var openOutputs: [ObjectIdentifier: SCRecordingOutput] = [:]
    private var finishedOutputs: [ObjectIdentifier: Error?] = [:]
    private var waiters: [ObjectIdentifier: CheckedContinuation<Void, Error>] = [:]
    private var stopped = false
    /// H.264 for what every player plays; HEVC for displays too large for it (5K and up).
    private var videoCodec: AVVideoCodecType = .h264

    init(options: Options) throws {
        self.options = options
        directory = FileManager.default.temporaryDirectory
            .appending(path: "Recording-\(UUID().uuidString)", directoryHint: .isDirectory)
        super.init()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: Starting

    func start() async throws {
        guard options.kind == .screen || options.microphone || options.systemAudio else {
            throw RecorderError.nothingToRecord
        }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let wanted = options.displayID == 0 ? CGMainDisplayID() : options.displayID
        guard let display = content.displays.first(where: { $0.displayID == wanted })
                ?? content.displays.first(where: { $0.displayID == CGMainDisplayID() })
                ?? content.displays.first else { throw RecorderError.noDisplay }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let topsail = options.showsIsland ? [] : content.applications.filter { $0.processID == ownPID }
        let filter = SCContentFilter(display: display, excludingApplications: topsail, exceptingWindows: [])

        let configuration = SCStreamConfiguration()
        switch options.kind {
        case .screen:
            let scale = CGFloat(filter.pointPixelScale)
            var width = filter.contentRect.width * scale
            var height = filter.contentRect.height * scale
            if width * height > Self.largestH264Frame {
                if SCRecordingOutputConfiguration().availableVideoCodecTypes.contains(.hevc) {
                    videoCodec = .hevc
                } else {
                    let fit = (Self.largestH264Frame / (width * height)).squareRoot()
                    width *= fit
                    height *= fit
                }
            }
            // Even sizes, as video encoders want.
            configuration.width = Int(width / 2) * 2
            configuration.height = Int(height / 2) * 2
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
            configuration.showsCursor = true
        case .call:
            configuration.width = 2
            configuration.height = 2
            configuration.minimumFrameInterval = CMTime(value: 1, timescale: 1)
            configuration.showsCursor = false
        }
        configuration.capturesAudio = options.systemAudio
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        configuration.excludesCurrentProcessAudio = true
        configuration.captureMicrophone = options.microphone
        if options.microphone {
            configuration.microphoneCaptureDeviceID = AVCaptureDevice.default(for: .audio)?.uniqueID
        }

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        if options.systemAudio {
            try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: queue)
        }
        if options.microphone {
            try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: queue)
        }
        switch options.kind {
        case .screen:
            try addPiece(to: stream)
        case .call:
            // The picture isn't kept; taking it here stops the stream complaining it has nowhere to go.
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
            var sources: Set<AudioFileWriter.Source> = []
            if options.systemAudio { sources.insert(.system) }
            if options.microphone { sources.insert(.microphone) }
            let writer = try AudioFileWriter(url: directory.appending(path: "call.m4a"), sources: sources)
            queue.sync { onQueue.writer = writer }
        }
        self.stream = stream
        do {
            try await stream.startCapture()
        } catch {
            self.stream = nil
            queue.sync { onQueue.writer?.cancel() }
            throw error
        }
    }

    /// A new piece of the movie, recorded from now until the next pause or the end.
    private func addPiece(to stream: SCStream) throws {
        let configuration = SCRecordingOutputConfiguration()
        let fileType = configuration.availableOutputFileTypes.contains(options.format.fileType)
            ? options.format.fileType : .mp4
        let url = directory.appending(path: "piece-\(pieceOrder.count + 1)")
            .appendingPathExtension(fileType == .mov ? "mov" : "mp4")
        configuration.outputURL = url
        configuration.outputFileType = fileType
        configuration.videoCodecType = videoCodec
        if #available(macOS 27.0, *) {
            configuration.mixesAudioWithMicrophone = !options.separateTracks
        }
        let output = SCRecordingOutput(configuration: configuration, delegate: self)
        try stream.addRecordingOutput(output)
        pieceOrder.append((ObjectIdentifier(output), url))
        openOutputs[ObjectIdentifier(output)] = output
        recordingOutput = output
    }

    // MARK: Pausing

    func pause() async throws {
        let now = Self.hostTime
        switch options.kind {
        case .screen:
            guard let stream, let output = recordingOutput else { return }
            recordingOutput = nil
            try stream.removeRecordingOutput(output)
            try await finished(output)
        case .call:
            queue.async { [onQueue] in onQueue.writer?.pause(at: now) }
        }
    }

    func resume() throws {
        let now = Self.hostTime
        switch options.kind {
        case .screen:
            guard let stream, recordingOutput == nil else { return }
            try addPiece(to: stream)
        case .call:
            queue.async { [onQueue] in onQueue.writer?.resume(at: now) }
        }
    }

    // MARK: Stopping

    /// Stops capturing and closes the files: the movie's pieces in order, or the call's file.
    func stop() async throws -> [URL] {
        guard !stopped else { return [] }
        stopped = true
        recordingOutput = nil
        if let stream {
            self.stream = nil
            // Already stopped if the system ended it; the files are closed either way.
            try? await stream.stopCapture()
        }
        switch options.kind {
        case .screen:
            // Including a piece still closing from a pause just before.
            for output in openOutputs.values { try? await finished(output) }
            let pieces = pieceOrder.filter { piece in
                finishedOutputs[piece.id].map { $0 == nil } == true && FileManager.default.fileExists(atPath: piece.url.path)
            }.map(\.url)
            guard !pieces.isEmpty else { throw RecorderError.nothingRecorded }
            return pieces
        case .call:
            let writer = queue.sync { () -> AudioFileWriter? in
                defer { onQueue.writer = nil }
                return onQueue.writer
            }
            guard let writer else { throw RecorderError.nothingRecorded }
            try await writer.finish()
            return [directory.appending(path: "call.m4a")]
        }
    }

    /// Stops and throws everything away.
    func cancel() async {
        _ = try? await stop()
        removeFiles()
    }

    func removeFiles() {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Waits until `output` has closed its file (it says so through its delegate).
    private func finished(_ output: SCRecordingOutput) async throws {
        let id = ObjectIdentifier(output)
        if let result = finishedOutputs[id] {
            if let error = result { throw error }
            return
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            waiters[id] = continuation
            // Never wait forever on a file that will not close.
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
                MainActor.assumeIsolated {
                    self?.waiters.removeValue(forKey: id)?.resume(throwing: RecorderError.cannotWrite(
                        String(localized: "The recording didn't finish writing.")))
                }
            }
        }
    }

    private func outputFinished(_ id: ObjectIdentifier, error: Error?) {
        guard finishedOutputs[id] == nil else { return }
        finishedOutputs[id] = .some(error)
        openOutputs.removeValue(forKey: id)
        if let waiter = waiters.removeValue(forKey: id) {
            if let error { waiter.resume(throwing: error) } else { waiter.resume() }
        } else if let error, !stopped {
            onInterrupted?(error)
        }
    }

    private static var hostTime: CMTime { CMClockGetTime(CMClockGetHostTimeClock()) }

    /// H.264's largest frame (level 5.2): 4096 × 2304 pixels.
    private static let largestH264Frame: CGFloat = 4096 * 2304
}

// MARK: - Samples, on the capture queue

/// What the capture queue owns: the call's writer and the level meters' running peaks. Only
/// ever touched on that queue, which is what makes it safe to share.
private final class QueueState: @unchecked Sendable {
    var writer: AudioFileWriter?
    var systemPeak: Float = 0
    var microphonePeak: Float = 0
    var lastReport: CFAbsoluteTime = 0
}

extension CaptureSession: SCStreamOutput {
    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
                            of type: SCStreamOutputType) {
        // Runs on `queue`, the only place `onQueue` is touched.
        let state = onQueue
        switch type {
        case .audio:
            state.writer?.append(sampleBuffer, from: .system)
            state.systemPeak = max(state.systemPeak, Self.level(of: sampleBuffer))
        case .microphone:
            state.writer?.append(sampleBuffer, from: .microphone)
            state.microphonePeak = max(state.microphonePeak, Self.level(of: sampleBuffer))
        default:
            return
        }
        let now = CFAbsoluteTimeGetCurrent()
        guard now - state.lastReport >= 1.0 / 12 else { return }
        let levels = (state.systemPeak, state.microphonePeak)
        state.lastReport = now
        state.systemPeak = 0
        state.microphonePeak = 0
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.onLevels?(levels.0, levels.1) }
        }
    }

    /// 0...1 on a 50 dB scale, from the buffer's loudest-channel RMS.
    nonisolated private static func level(of buffer: CMSampleBuffer) -> Float {
        guard let description = buffer.formatDescription,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description)?.pointee else { return 0 }
        let isFloat = asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0
        let bits = asbd.mBitsPerChannel
        var loudest: Float = 0
        try? buffer.withAudioBufferList { list, _ in
            for audio in list {
                guard let data = audio.mData, audio.mDataByteSize > 0 else { continue }
                var sum: Float = 0
                var count = 0
                if isFloat && bits == 32 {
                    let samples = data.assumingMemoryBound(to: Float.self)
                    count = Int(audio.mDataByteSize) / 4
                    for index in 0..<count { sum += samples[index] * samples[index] }
                } else if !isFloat && bits == 16 {
                    let samples = data.assumingMemoryBound(to: Int16.self)
                    count = Int(audio.mDataByteSize) / 2
                    for index in 0..<count {
                        let sample = Float(samples[index]) / 32768
                        sum += sample * sample
                    }
                }
                if count > 0 { loudest = max(loudest, (sum / Float(count)).squareRoot()) }
            }
        }
        guard loudest > 0 else { return 0 }
        let decibels = 20 * log10(loudest)
        return min(max((decibels + 50) / 50, 0), 1)
    }
}

extension CaptureSession: SCStreamDelegate {
    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.stopped else { return }
                self.onInterrupted?(error)
            }
        }
    }
}

extension CaptureSession: SCRecordingOutputDelegate {
    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        let id = ObjectIdentifier(recordingOutput)
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.outputFinished(id, error: nil) }
        }
    }

    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: Error) {
        let id = ObjectIdentifier(recordingOutput)
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.outputFinished(id, error: error) }
        }
    }
}
