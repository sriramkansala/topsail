import AVFoundation
import CoreMedia

/// Writes a call as it happens: what the Mac plays and the microphone, each in its own AAC track
/// of one .m4a. Used only on the capture queue.
///
/// Pausing drops what arrives and closes the gap: everything after a pause is moved back by the
/// pause's length, on both tracks alike, so they stay in step and the file has no hole.
final class AudioFileWriter {
    enum Source: Hashable {
        case system
        case microphone
    }

    private let writer: AVAssetWriter
    private var inputs: [Source: AVAssetWriterInput] = [:]
    private var sessionStart: CMTime?
    /// The host time a pause began, while paused.
    private var pausedAt: CMTime?
    /// Anything captured before this host time is from a pause and is dropped.
    private var resumedAt: CMTime = .zero
    /// The time taken out by pauses so far.
    private var offset: CMTime = .zero
    private var finished = false

    init(url: URL, sources: Set<Source>) throws {
        guard !sources.isEmpty else { throw RecorderError.nothingToRecord }
        writer = try AVAssetWriter(outputURL: url, fileType: .m4a)
        // The Mac's sound first: a player that plays one track plays the other side of the call.
        for source in [Source.system, .microphone] where sources.contains(source) {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: Self.settings(for: source))
            input.expectsMediaDataInRealTime = true
            guard writer.canAdd(input) else {
                throw RecorderError.cannotWrite(String(localized: "Topsail couldn't set up the recording."))
            }
            writer.add(input)
            inputs[source] = input
        }
        guard writer.startWriting() else {
            throw writer.error ?? RecorderError.cannotWrite(String(localized: "Topsail couldn't set up the recording."))
        }
    }

    /// AAC at 48 kHz: stereo for the Mac's sound, mono for the microphone. The writer converts
    /// whatever rate and layout the device delivers.
    static func settings(for source: Source) -> [String: Any] {
        [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: source == .system ? 2 : 1,
            AVEncoderBitRateKey: source == .system ? 128_000 : 96_000,
        ]
    }

    func append(_ buffer: CMSampleBuffer, from source: Source) {
        guard !finished, let input = inputs[source], buffer.isValid, buffer.numSamples > 0 else { return }
        let time = buffer.presentationTimeStamp
        guard time.isValid, time >= resumedAt else { return }
        if let pausedAt, time >= pausedAt { return }

        let start = time - offset
        if sessionStart == nil {
            writer.startSession(atSourceTime: start)
            sessionStart = start
        }
        guard let sessionStart, start >= sessionStart, input.isReadyForMoreMediaData else { return }
        if offset == .zero {
            input.append(buffer)
        } else if let moved = Self.retimed(buffer, by: offset) {
            input.append(moved)
        }
    }

    /// `time`: the host time the user paused.
    func pause(at time: CMTime) {
        guard pausedAt == nil else { return }
        pausedAt = time
    }

    /// `time`: the host time the user resumed.
    func resume(at time: CMTime) {
        guard let pausedAt else { return }
        offset = offset + (time - pausedAt)
        resumedAt = time
        self.pausedAt = nil
    }

    /// Closes the file. Throws when nothing was recorded at all.
    func finish() async throws {
        guard !finished else { return }
        finished = true
        guard sessionStart != nil else {
            writer.cancelWriting()
            throw RecorderError.nothingRecorded
        }
        inputs.values.forEach { $0.markAsFinished() }
        await writer.finishWriting()
        if writer.status != .completed {
            throw writer.error ?? RecorderError.nothingRecorded
        }
    }

    /// Stops without keeping anything.
    func cancel() {
        guard !finished else { return }
        finished = true
        writer.cancelWriting()
    }

    private static func retimed(_ buffer: CMSampleBuffer, by offset: CMTime) -> CMSampleBuffer? {
        guard var timing = try? buffer.sampleTimingInfos() else { return nil }
        for index in timing.indices {
            timing[index].presentationTimeStamp = timing[index].presentationTimeStamp - offset
            if timing[index].decodeTimeStamp.isValid {
                timing[index].decodeTimeStamp = timing[index].decodeTimeStamp - offset
            }
        }
        return try? CMSampleBuffer(copying: buffer, withNewTiming: timing)
    }
}

/// What happens to a recording's file between the capture stopping and the notice saying "Saved".
enum RecordingFiles {
    /// Pieces of a screen recording, one per stretch between pauses, joined end to end without
    /// re-encoding.
    static func join(_ pieces: [URL], into destination: URL, as fileType: AVFileType) async throws {
        let composition = AVMutableComposition()
        var cursor = CMTime.zero
        for piece in pieces {
            let asset = AVURLAsset(url: piece)
            let duration = try await asset.load(.duration)
            guard duration > .zero else { continue }
            try await composition.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: asset, at: cursor)
            cursor = cursor + duration
        }
        guard cursor > .zero else { throw RecorderError.nothingRecorded }
        guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw RecorderError.cannotWrite(String(localized: "Topsail couldn't join the recording's parts."))
        }
        try await export.export(to: destination, as: fileType)
    }

    /// A call's two tracks (the other side, you) mixed into one, as most players and transcribers
    /// expect.
    static func mix(_ source: URL, into destination: URL) async throws {
        let asset = AVURLAsset(url: source)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard !tracks.isEmpty else { throw RecorderError.nothingRecorded }

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderAudioMixOutput(audioTracks: tracks, audioSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false,
        ])
        guard reader.canAdd(output) else { throw RecorderError.cannotWrite(String(localized: "Topsail couldn't mix the call.")) }
        reader.add(output)

        let writer = try AVAssetWriter(outputURL: destination, fileType: .m4a)
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: AudioFileWriter.settings(for: .system))
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else { throw RecorderError.cannotWrite(String(localized: "Topsail couldn't mix the call.")) }
        writer.add(input)

        guard reader.startReading() else { throw reader.error ?? RecorderError.nothingRecorded }
        guard writer.startWriting() else { throw writer.error ?? RecorderError.nothingRecorded }
        writer.startSession(atSourceTime: .zero)

        let pump = MixPump(reader: reader, output: output, input: input)
        await pump.run()
        if reader.status == .failed {
            writer.cancelWriting()
            throw reader.error ?? RecorderError.nothingRecorded
        }
        await writer.finishWriting()
        if writer.status != .completed { throw writer.error ?? RecorderError.nothingRecorded }
    }
}

/// Moves a mixed call from the reader to the writer as fast as the writer takes it.
private final class MixPump: @unchecked Sendable {
    private let reader: AVAssetReader
    private let output: AVAssetReaderOutput
    private let input: AVAssetWriterInput
    private let queue = DispatchQueue(label: "app.topsail.recorder.mix")

    init(reader: AVAssetReader, output: AVAssetReaderOutput, input: AVAssetWriterInput) {
        self.reader = reader
        self.output = output
        self.input = input
    }

    func run() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            var done = false
            input.requestMediaDataWhenReady(on: queue) { [self] in
                guard !done else { return }
                while input.isReadyForMoreMediaData {
                    if reader.status == .reading, let buffer = output.copyNextSampleBuffer() {
                        input.append(buffer)
                    } else {
                        done = true
                        input.markAsFinished()
                        continuation.resume()
                        return
                    }
                }
            }
        }
    }
}
