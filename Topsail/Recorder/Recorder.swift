import AppKit
import AVFoundation
import Combine
import ScreenCaptureKit

/// The two sounds' levels while recording, 0...1. Apart from `Recorder` so that only the meters
/// redraw a dozen times a second, never the island.
@MainActor
final class RecorderLevels: ObservableObject {
    /// What the Mac plays (the other side of a call).
    @Published private(set) var system: Float = 0
    /// The microphone (you).
    @Published private(set) var microphone: Float = 0

    func update(system: Float, microphone: Float) {
        // Rises at once, falls gently, like a meter's needle.
        self.system = max(system, self.system * 0.6)
        self.microphone = max(microphone, self.microphone * 0.6)
    }

    func reset() {
        system = 0
        microphone = 0
    }
}

/// Time recorded: what was recorded before the current stretch, and when that stretch began
/// (nil while paused). Views work out the time from it as they draw, so nothing ticks here.
struct RecordingClock: Equatable {
    var recorded: TimeInterval = 0
    var runningSince: Date?

    func elapsed(at date: Date) -> TimeInterval {
        recorded + (runningSince.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    /// "0:05", "12:34", "1:02:34".
    static func format(_ time: TimeInterval) -> String {
        let seconds = max(0, Int(time))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, seconds % 60)
            : String(format: "%d:%02d", minutes, seconds % 60)
    }
}

/// A display the screen recording can be of.
struct RecordableDisplay: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
}

/// Records the screen or a call, started, watched and stopped from the notch.
///
/// Every step is the user's: a screen recording counts down 3-2-1 (the island closes first, so it
/// isn't in the picture), a call is recorded only when asked — from the Record page, or from the
/// offer after joining a call — and, the first time, only after a reminder that recording laws
/// may require telling everyone on the call. While it runs, the closed island shows a red dot and
/// the time; stopping saves the file and a notice grows out of the notch to say so.
@MainActor
final class Recorder: ObservableObject {
    enum Permission: Equatable {
        case screenRecording
        case microphone
    }

    enum Phase: Equatable {
        case idle
        /// Waiting on a permission; the Record page says where to allow it.
        case needsPermission(Permission, RecordingKind)
        /// The one-time reminder before the first call recording, on the Record page.
        case consent
        /// The screen recording starts in 3, 2, 1.
        case countdown(Int)
        case starting(RecordingKind)
        case recording(RecordingKind)
        /// Stopped; the file is being closed (and joined, or mixed) and moved to its folder.
        case saving(RecordingKind)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var isPaused = false
    @Published private(set) var clock = RecordingClock()
    let levels = RecorderLevels()
    let settings = RecorderSettings()

    /// Whether the feature is on (Settings › Features).
    var isEnabled: () -> Bool = { false }
    /// Notices in the notch: show one, change one in place, take one away.
    var postNotice: (RecorderNotice) -> Void = { _ in }
    var replaceNotice: (RecorderNotice, RecorderNotice) -> Void = { _, _ in }
    var withdrawNotice: (RecorderNotice) -> Void = { _ in }
    /// A screen recording is counting down: the island closes, so it isn't in the first frames.
    var onCountdown: () -> Void = {}

    private var session: CaptureSession?
    private var startTask: Task<Void, Never>?
    /// The call being recorded, for the file's name.
    private var meetingTitle: String?
    /// A call recording waiting on the reminder, from the Record page.
    private var pendingMeeting: UpcomingEvent?
    /// Waiting for the recording being saved (Topsail quitting).
    private var savedWaiters: [() -> Void] = []

    // MARK: What the island shows

    /// The kind being recorded, counted down to, or saved.
    var kind: RecordingKind? {
        switch phase {
        case .countdown: return .screen
        case .starting(let kind), .recording(let kind), .saving(let kind): return kind
        case .idle, .needsPermission, .consent: return nil
        }
    }

    var isRecording: Bool {
        if case .recording = phase { return true }
        return false
    }

    var isCountingDown: Bool {
        if case .countdown = phase { return true }
        return false
    }

    /// Counting down, recording or saving: the closed island shows it in its wings, and the open
    /// island opens to the Record page.
    var showsWings: Bool { kind != nil }

    /// Below the camera, for the countdown's digit.
    var stageHeight: CGFloat {
        isCountingDown ? RecorderLayout.countdownStageHeight : 0
    }

    /// The Record page's height for what it shows now.
    var pageHeight: CGFloat {
        switch phase {
        case .idle: return RecorderLayout.idleHeight
        case .recording: return RecorderLayout.recordingHeight
        case .needsPermission, .consent, .countdown, .starting, .saving: return RecorderLayout.messageHeight
        }
    }

    /// Displays that can be recorded; the Record page offers a choice when there's more than one.
    var displays: [RecordableDisplay] {
        NSScreen.screens.compactMap { screen in
            guard let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return nil }
            return RecordableDisplay(id: id, name: screen.localizedName)
        }
    }

    /// The display a screen recording will be of: the chosen one if it's connected, else the one
    /// with the island.
    var selectedDisplay: CGDirectDisplayID {
        let connected = displays.map(\.id)
        if settings.displayID != 0, connected.contains(settings.displayID) { return settings.displayID }
        let notch = NotchGeometry.targetScreen()?
            .deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        return notch ?? CGMainDisplayID()
    }

    func selectDisplay(_ id: CGDirectDisplayID) {
        settings.displayID = id
        objectWillChange.send()
    }

    // MARK: Starting

    private var canStart: Bool {
        switch phase {
        case .idle, .needsPermission, .consent: return isEnabled()
        default: return false
        }
    }

    func recordScreen() {
        guard canStart else { return }
        startTask = Task { await begin(.screen, meeting: nil) }
    }

    /// Records a call, after the one-time reminder about recording laws.
    func recordCall(meeting: UpcomingEvent? = nil) {
        guard canStart else { return }
        guard settings.consentShown else {
            pendingMeeting = meeting
            Motion.perform(Motion.snappy) { phase = .consent }
            return
        }
        startTask = Task { await begin(.call, meeting: meeting) }
    }

    /// "Record" under the reminder on the Record page.
    func acceptConsent() {
        guard phase == .consent else { return }
        settings.consentShown = true
        let meeting = pendingMeeting
        pendingMeeting = nil
        phase = .idle
        recordCall(meeting: meeting)
    }

    /// Cancel on the Record page: a reminder, a missing permission, or the countdown.
    func cancel() {
        switch phase {
        case .needsPermission, .consent:
            pendingMeeting = nil
            Motion.perform(Motion.snappy) { phase = .idle }
        case .countdown:
            startTask?.cancel()
            startTask = nil
            let session = self.session
            self.session = nil
            Motion.perform(Motion.islandShrink) { phase = .idle }
            Task { await session?.cancel() }
        default:
            break
        }
    }

    /// Opens the Privacy & Security list for the permission the Record page is asking about.
    func openPermissionSettings() {
        guard case .needsPermission(let permission, _) = phase else { return }
        SystemSettings.open(permission == .screenRecording ? "Privacy_ScreenCapture" : "Privacy_Microphone")
    }

    private func begin(_ kind: RecordingKind, meeting: UpcomingEvent?) async {
        // Permissions first. macOS asks the first time; after that the Record page says where to
        // allow them. Topsail never changes them itself.
        guard Self.screenAccess() else {
            Motion.perform(Motion.snappy) { phase = .needsPermission(.screenRecording, kind) }
            return
        }
        if settings.microphone, !(await Self.microphoneAccess()) {
            Motion.perform(Motion.snappy) { phase = .needsPermission(.microphone, kind) }
            return
        }
        if kind == .call, !settings.microphone, !settings.systemAudio {
            return fail(RecorderError.nothingToRecord)
        }

        let options = CaptureSession.Options(kind: kind, displayID: selectedDisplay, microphone: settings.microphone,
                                             systemAudio: settings.systemAudio, separateTracks: settings.separateTracks,
                                             format: settings.format, showsIsland: settings.showsIsland)
        let session: CaptureSession
        do {
            session = try CaptureSession(options: options)
        } catch {
            return fail(error)
        }
        session.onLevels = { [weak self] system, microphone in
            self?.levels.update(system: system, microphone: microphone)
        }
        // Stopped from the menu bar's recording indicator, or the display went away: save what's there.
        session.onInterrupted = { [weak self] _ in self?.stop() }
        self.session = session
        meetingTitle = meeting?.title

        if kind == .screen {
            onCountdown()
            for count in [3, 2, 1] {
                Motion.perform(count == 3 ? Motion.notice : Motion.snappy) { phase = .countdown(count) }
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled || self.session !== session { return }
            }
        }
        phase = .starting(kind)
        do {
            try await session.start()
        } catch {
            session.removeFiles()
            if self.session === session { self.session = nil }
            return fail(error)
        }
        guard self.session === session else { return }
        clock = RecordingClock(recorded: 0, runningSince: Date())
        isPaused = false
        Motion.perform(kind == .screen ? Motion.notice : Motion.islandGrow) { phase = .recording(kind) }
        startTask = nil
    }

    private func fail(_ error: Error) {
        session = nil
        startTask = nil
        Motion.perform(Motion.islandShrink) { phase = .idle }
        levels.reset()
        postNotice(.failed(Self.message(for: error)))
    }

    // MARK: Pausing and stopping

    func pause() {
        guard isRecording, !isPaused, let session else { return }
        clock = RecordingClock(recorded: clock.elapsed(at: Date()), runningSince: nil)
        Motion.perform(Motion.snappy) { isPaused = true }
        Task {
            do { try await session.pause() } catch { stop() }
        }
    }

    func resume() {
        guard isRecording, isPaused, let session else { return }
        do {
            try session.resume()
        } catch {
            return stop()
        }
        clock.runningSince = Date()
        Motion.perform(Motion.snappy) { isPaused = false }
    }

    func togglePause() {
        isPaused ? resume() : pause()
    }

    /// Stops and saves; a notice says where. `completion` runs once the file is saved (or not).
    func stop(completion: (() -> Void)? = nil) {
        guard case .recording(let kind) = phase else {
            if case .countdown = phase { cancel() }
            completion?()
            return
        }
        let duration = clock.elapsed(at: Date())
        let separateTracks = session?.options.separateTracks ?? settings.separateTracks
        let session = self.session
        clock = RecordingClock(recorded: duration, runningSince: nil)
        isPaused = false
        Motion.perform(Motion.snappy) { phase = .saving(kind) }
        Task {
            if let session {
                do {
                    let files = try await session.stop()
                    let url = try await save(files, kind: kind, separateTracks: separateTracks, in: session.directory)
                    postNotice(.saved(SavedRecording(url: url, kind: kind, duration: duration)))
                } catch {
                    postNotice(.failed(Self.message(for: error)))
                }
                session.removeFiles()
            }
            if self.session === session { self.session = nil }
            meetingTitle = nil
            levels.reset()
            Motion.perform(Motion.islandShrink) { phase = .idle }
            completion?()
            savedWaiters.forEach { $0() }
            savedWaiters = []
        }
    }

    /// Topsail is quitting: a recording is stopped and saved first, then `completion` runs.
    func finish(then completion: @escaping () -> Void) {
        switch phase {
        case .recording: stop(completion: completion)
        case .saving: savedWaiters.append(completion)
        case .countdown, .starting:
            startTask?.cancel()
            let session = self.session
            self.session = nil
            phase = .idle
            Task {
                await session?.cancel()
                completion()
            }
        default: completion()
        }
    }

    /// The feature was switched off: a recording is saved, a countdown dropped.
    func featureTurnedOff() {
        switch phase {
        case .recording: stop()
        case .countdown: cancel()
        case .needsPermission, .consent: cancel()
        default: break
        }
    }

    /// Joins the pieces, or mixes the call, then moves the file into the folder under a name that
    /// says what and when.
    private func save(_ files: [URL], kind: RecordingKind, separateTracks: Bool, in directory: URL) async throws -> URL {
        guard let first = files.first else { throw RecorderError.nothingRecorded }
        var file = first
        switch kind {
        case .screen where files.count > 1:
            file = directory.appending(path: "joined").appendingPathExtension(first.pathExtension)
            try await RecordingFiles.join(files, into: file, as: first.pathExtension == "mov" ? .mov : .mp4)
        case .call where !separateTracks:
            let tracks = try await AVURLAsset(url: first).loadTracks(withMediaType: .audio)
            if tracks.count > 1 {
                file = directory.appending(path: "mixed.m4a")
                try await RecordingFiles.mix(first, into: file)
            }
        default:
            break
        }
        let name = fileName(for: kind)
        return try settings.withFolderAccess { folder in
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            var destination = folder.appending(path: name).appendingPathExtension(file.pathExtension)
            var copy = 2
            while FileManager.default.fileExists(atPath: destination.path) {
                destination = folder.appending(path: "\(name) \(copy)").appendingPathExtension(file.pathExtension)
                copy += 1
            }
            do {
                try FileManager.default.moveItem(at: file, to: destination)
            } catch {
                throw RecorderError.cannotWrite(String(localized: "Topsail couldn't save to \(settings.folderDisplayPath)."))
            }
            return destination
        }
    }

    /// "Screen recording 2026-11-27 14.03.12", or the call's title from the calendar.
    private func fileName(for kind: RecordingKind) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH.mm.ss"
        let title = meetingTitle.map(Self.safeFileName).flatMap { $0.isEmpty ? nil : $0 } ?? kind.title
        return "\(title) \(formatter.string(from: Date()))"
    }

    private static func safeFileName(_ text: String) -> String {
        let cleaned = text.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return String(cleaned.prefix(80))
    }

    private static func message(for error: Error) -> String {
        if let error = error as? RecorderError, let text = error.errorDescription { return text }
        let error = error as NSError
        if error.domain == SCStreamErrorDomain, error.code == SCStreamError.userDeclined.rawValue {
            return RecorderError.screenRecordingDenied.errorDescription ?? ""
        }
        return error.localizedDescription
    }

    // MARK: A saved recording

    /// Opens it in its app, with the folder open to Topsail (a chosen folder is security-scoped
    /// in the App Store build).
    func open(_ saved: SavedRecording) {
        settings.withFolderAccess { _ in NSWorkspace.shared.open(saved.url) }
    }

    func showInFinder(_ saved: SavedRecording) {
        settings.withFolderAccess { _ in NSWorkspace.shared.activateFileViewerSelecting([saved.url]) }
    }

    // MARK: The offer after joining a call

    /// A call from the calendar was joined (the meeting reminder's Join): offer to record it.
    /// Never starts by itself.
    func offerCall(for meeting: UpcomingEvent) {
        guard isEnabled(), settings.offerForCalls, phase == .idle else { return }
        postNotice(.offer(meeting))
    }

    /// Record or Not now on the offer, or Record or Cancel on the reminder after it.
    func answer(_ notice: RecorderNotice, record: Bool) {
        switch notice {
        case .offer(let meeting) where record && !settings.consentShown:
            replaceNotice(notice, .consent(meeting))
        case .offer(let meeting) where record:
            withdrawNotice(notice)
            recordCall(meeting: meeting)
        case .consent(let meeting) where record:
            withdrawNotice(notice)
            settings.consentShown = true
            recordCall(meeting: meeting)
        default:
            withdrawNotice(notice)
        }
    }

    // MARK: Permissions

    /// Screen Recording (ScreenCaptureKit needs it for sound too). Asks the first time; macOS shows
    /// its own prompt, and the answer applies from the next try.
    private static func screenAccess() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        return CGRequestScreenCaptureAccess()
    }

    private static func microphoneAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: .audio)
        default: return false
        }
    }

    // MARK: Debug previews

    #if DEBUG
    /// `topsail://preview/recording` (and `/recording-paused`, `/recording-call`, `/countdown`,
    /// `/recording-saved`, `/recording-offer`, `/recording-consent`): the recorder's states,
    /// without recording anything.
    func preview(_ name: String) {
        let meeting = UpcomingEvent(id: "preview-recording", title: "Design review", start: Date(),
                                    end: Date().addingTimeInterval(1800), isAllDay: false, color: .purple,
                                    joinURL: URL(string: "https://zoom.us/test"))
        switch name {
        case "recording", "recording-paused", "recording-call":
            clock = RecordingClock(recorded: name == "recording-paused" ? 754 : 0,
                                   runningSince: name == "recording-paused" ? nil : Date().addingTimeInterval(-754))
            isPaused = name == "recording-paused"
            Motion.perform(Motion.notice) { phase = .recording(name == "recording-call" ? .call : .screen) }
        case "countdown":
            Task {
                for count in [3, 2, 1] {
                    Motion.perform(count == 3 ? Motion.notice : Motion.snappy) { phase = .countdown(count) }
                    try? await Task.sleep(for: .seconds(1))
                }
                Motion.perform(Motion.notice) { phase = .idle }
            }
        case "recording-saved":
            postNotice(.saved(SavedRecording(url: settings.folder.appending(path: "Screen recording.mov"),
                                             kind: .screen, duration: 154)))
        case "recording-offer":
            postNotice(.offer(meeting))
        case "recording-consent":
            postNotice(.consent(meeting))
        default:
            break
        }
    }
    #endif
}
