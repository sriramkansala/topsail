import AppKit
import SwiftUI

extension EnvironmentValues {
    /// The recorder, for views deep in the island (its notices) that act on it.
    @Entry var recorder: Recorder? = nil
}

/// Apple's colours for recording: red records, the rest stay white.
enum RecorderColors {
    static let red = Color(nsColor: .systemRed)
    static let orange = Color(nsColor: .systemOrange)
    static let green = Color(nsColor: .systemGreen)
    static let blue = Color(nsColor: .systemBlue)
}

// MARK: - The closed island

/// Beside the camera while recording: a red dot in the left wing and the time in the right one;
/// during the countdown, the digit hangs below the camera. `rowOnly` keeps just the notch row,
/// over a notice that shows below it, so the recording never drops out of sight.
struct RecordingWings: View {
    @ObservedObject var recorder: Recorder
    let notchSize: CGSize
    let wingWidth: CGFloat
    var rowOnly = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                RecorderDot(paused: recorder.isPaused, live: recorder.isRecording)
                    .padding(.leading, RecorderLayout.wingInset)
                    .frame(width: wingWidth, height: notchSize.height, alignment: .leading)

                Color.clear
                    .frame(width: notchSize.width, height: notchSize.height)

                ZStack(alignment: .trailing) {
                    if !recorder.isCountingDown {
                        RecordingTime(clock: recorder.clock, paused: recorder.isPaused || !recorder.isRecording)
                            .transition(.cascade(1, reduceMotion: reduceMotion))
                    }
                }
                .padding(.trailing, RecorderLayout.wingInset)
                .frame(width: wingWidth, height: notchSize.height, alignment: .trailing)
            }

            if !rowOnly, case .countdown(let count) = recorder.phase {
                Text(verbatim: "\(count)")
                    .font(.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))
                    .frame(height: RecorderLayout.countdownStageHeight - 6)
                    .transition(.noticeBlur(reduceMotion: reduceMotion))
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: Text {
        switch recorder.phase {
        case .countdown(let count): return Text("Recording starts in \(count)")
        case .saving: return Text("Saving the recording")
        default:
            let time = RecordingClock.format(recorder.clock.elapsed(at: Date()))
            return recorder.isPaused ? Text("Recording paused at \(time)") : Text("Recording, \(time)")
        }
    }
}

extension RecordingWings {
    /// Notices whose card hangs below an empty notch row: the recording's wings stay in that row
    /// while they show. (The others are wings themselves, and only show for a moment.)
    static func sharesRow(with kind: ActivityKind?) -> Bool {
        switch kind {
        case .lowBattery, .meetingReminder, .agentApproval, .notification, .recorder: return true
        default: return false
        }
    }
}

/// The red dot that says "recording". It breathes while recording, holds still while counting
/// down or saving, and becomes a pause glyph while paused.
struct RecorderDot: View {
    let paused: Bool
    /// Recording right now (not counting down, starting or saving).
    var live = true
    var size: CGFloat = RecorderLayout.dotSize

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if paused {
                Image(systemName: "pause.fill")
                    .font(.system(size: size + 1, weight: .bold))
                    .foregroundStyle(.white.opacity(0.75))
                    .transition(CompactMusicWings.swap(reduceMotion))
            } else {
                Circle()
                    .fill(RecorderColors.red)
                    .frame(width: size, height: size)
                    .phaseAnimator(live && !reduceMotion ? [1.0, 0.4] : [1.0]) { dot, opacity in
                        dot.opacity(opacity)
                    } animation: { _ in
                        Motion.easeInOut(Motion.Duration.spin)
                    }
                    .transition(CompactMusicWings.swap(reduceMotion))
            }
        }
        .frame(width: size + 4, height: size + 4)
        .accessibilityHidden(true)
    }
}

/// The time recorded, ticking each second; its digits roll. Dimmed while paused or saving.
struct RecordingTime: View {
    let clock: RecordingClock
    var paused = false
    var font: Font = .system(size: 12, weight: .semibold).monospacedDigit()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: clock.runningSince ?? Date(), by: 1)) { context in
            let seconds = Int(clock.elapsed(at: context.date))
            Text(verbatim: RecordingClock.format(TimeInterval(seconds)))
                .font(font)
                .foregroundStyle(.white.opacity(paused ? 0.5 : 1))
                .contentTransition(.numericText(value: Double(seconds)))
                .animation(reduceMotion ? nil : Motion.fast, value: seconds)
                .animation(reduceMotion ? nil : Motion.fast, value: paused)
        }
        .fixedSize()
    }
}

// MARK: - The open island

/// In the open island's notch row while recording on another page: the dot and the time, which
/// bring the Record page back.
struct RecordingRowBadge: View {
    @ObservedObject var recorder: Recorder
    let action: () -> Void

    var body: some View {
        if recorder.isRecording {
            Button(action: action) {
                HStack(spacing: 5) {
                    RecorderDot(paused: recorder.isPaused, live: true, size: 7)
                    RecordingTime(clock: recorder.clock, paused: recorder.isPaused,
                                  font: .system(size: 11, weight: .semibold).monospacedDigit())
                }
            }
            .buttonStyle(.pressable)
            .help("Recording: show the controls")
        }
    }
}

/// The Record page: Record screen and Record call, then the microphone, the Mac's sound and the
/// display. While recording, the time, both sounds' levels, Pause and Stop. Permissions, the
/// reminder before a first call and the countdown are said here too, in the island.
struct RecorderPageView: View {
    @ObservedObject var recorder: Recorder
    @ObservedObject var settings: RecorderSettings

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(recorder: Recorder) {
        self.recorder = recorder
        settings = recorder.settings
    }

    var body: some View {
        ZStack(alignment: .top) {
            switch recorder.phase {
            case .idle:
                idle.transition(.contentMorph(reduceMotion: reduceMotion))
            case .recording(let kind):
                recording(kind).transition(.contentMorph(reduceMotion: reduceMotion))
            case .needsPermission(let permission, let kind):
                permissionMessage(permission, kind).transition(.contentMorph(reduceMotion: reduceMotion))
            case .consent:
                consent.transition(.contentMorph(reduceMotion: reduceMotion))
            case .countdown(let count):
                message(symbol: "record.circle", tint: RecorderColors.red,
                        text: Text("Recording starts in \(count)…")) {
                    ReminderButton(title: String(localized: "Cancel")) { recorder.cancel() }
                }
                .transition(.contentMorph(reduceMotion: reduceMotion))
            case .starting:
                message(symbol: "record.circle", tint: RecorderColors.red, text: Text("Starting…")) { EmptyView() }
                    .transition(.contentMorph(reduceMotion: reduceMotion))
            case .saving:
                message(symbol: "square.and.arrow.down", tint: .white, text: Text("Saving…")) { EmptyView() }
                    .transition(.contentMorph(reduceMotion: reduceMotion))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    // MARK: Idle

    private var idle: some View {
        VStack(spacing: RecorderLayout.rowGap) {
            HStack(spacing: 8) {
                RecordTile(symbol: RecordingKind.screen.symbol, title: Text("Record screen"),
                           detail: Text(screenDetail)) { recorder.recordScreen() }
                RecordTile(symbol: RecordingKind.call.symbol, title: Text("Record call"),
                           detail: Text(callDetail)) { recorder.recordCall() }
                    .disabled(!settings.microphone && !settings.systemAudio)
            }
            HStack(spacing: 6) {
                RecorderChip(symbol: settings.microphone ? "mic.fill" : "mic.slash.fill", title: Text("Microphone"),
                             on: settings.microphone) { settings.microphone.toggle() }
                RecorderChip(symbol: settings.systemAudio ? "speaker.wave.2.fill" : "speaker.slash.fill",
                             title: Text("Mac sound"), on: settings.systemAudio) { settings.systemAudio.toggle() }
                Spacer(minLength: 0)
                let displays = recorder.displays
                if displays.count > 1 {
                    // A choice without a menu: each click moves to the next display.
                    RecorderChip(symbol: "display", title: Text(verbatim: displayName), on: true) {
                        let ids = displays.map(\.id)
                        let index = ids.firstIndex(of: recorder.selectedDisplay) ?? 0
                        recorder.selectDisplay(ids[(index + 1) % ids.count])
                    }
                    .help("Record another display")
                }
            }
            .frame(height: RecorderLayout.chipHeight)
            // Where the files go, and a way there.
            Button(action: settings.showFolder) {
                HStack(spacing: 5) {
                    Image(systemName: "folder")
                    Text("Saves to \(settings.folderBreadcrumb)")
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Image(systemName: "arrow.up.forward")
                        .font(.system(size: 8.5, weight: .bold))
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: RecorderLayout.folderRowHeight)
            }
            .buttonStyle(.pressable(.subtle))
            .help("Show the folder in Finder")
        }
    }

    private var displayName: String {
        recorder.displays.first { $0.id == recorder.selectedDisplay }?.name ?? ""
    }

    private var screenDetail: String {
        recorder.displays.count > 1 ? displayName : String(localized: "The whole screen")
    }

    private var callDetail: String {
        switch (settings.systemAudio, settings.microphone) {
        case (true, true): return String(localized: "Both sides")
        case (true, false): return String(localized: "Their side only")
        case (false, true): return String(localized: "Your side only")
        case (false, false): return String(localized: "Turn on a sound")
        }
    }

    // MARK: Recording

    private func recording(_ kind: RecordingKind) -> some View {
        VStack(spacing: RecorderLayout.rowGap) {
            HStack(spacing: 8) {
                RecorderDot(paused: recorder.isPaused, live: true)
                Group {
                    if recorder.isPaused {
                        Text("Paused")
                    } else if kind == .screen {
                        Text("Recording screen")
                    } else {
                        Text("Recording call")
                    }
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                Spacer(minLength: 8)
                RecordingTime(clock: recorder.clock, paused: recorder.isPaused,
                              font: .system(size: 22, weight: .semibold).monospacedDigit())
            }
            .frame(height: 30)
            HStack(spacing: 8) {
                RecorderLevelMeters(levels: recorder.levels, microphone: settings.microphone,
                                    systemAudio: settings.systemAudio)
                Spacer(minLength: 8)
                ReminderButton(title: recorder.isPaused ? String(localized: "Resume") : String(localized: "Pause"),
                               symbol: recorder.isPaused ? "record.circle" : "pause.fill") { recorder.togglePause() }
                ReminderButton(title: String(localized: "Stop"), symbol: "stop.fill", tint: RecorderColors.red) {
                    recorder.stop()
                }
            }
            .frame(height: RecorderLayout.buttonHeight)
        }
    }

    // MARK: Messages

    private var consent: some View {
        message(symbol: "exclamationmark.bubble.fill", tint: RecorderColors.orange,
                text: Text("Recording laws may require telling everyone on the call.")) {
            ReminderButton(title: String(localized: "Cancel")) { recorder.cancel() }
            ReminderButton(title: String(localized: "Record"), symbol: "record.circle", tint: RecorderColors.red) {
                recorder.acceptConsent()
            }
        }
    }

    private func permissionMessage(_ permission: Recorder.Permission, _ kind: RecordingKind) -> some View {
        message(symbol: "exclamationmark.triangle.fill", tint: RecorderColors.orange,
                text: permission == .screenRecording
                    ? Text("Allow Topsail under Privacy & Security › Screen & System Audio Recording.")
                    : Text("Allow Topsail under Privacy & Security › Microphone, or record without it.")) {
            ReminderButton(title: String(localized: "Cancel")) { recorder.cancel() }
            if permission == .microphone {
                ReminderButton(title: String(localized: "Without mic")) {
                    settings.microphone = false
                    kind == .screen ? recorder.recordScreen() : recorder.recordCall()
                }
            }
            ReminderButton(title: String(localized: "Open Settings"), tint: RecorderColors.blue) {
                recorder.openPermissionSettings()
            }
        }
    }

    /// A line of text by its glyph, and buttons under it on the right.
    private func message<Buttons: View>(symbol: String, tint: Color, text: Text,
                                        @ViewBuilder buttons: () -> Buttons) -> some View {
        VStack(alignment: .leading, spacing: RecorderLayout.rowGap) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 20)
                text
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: 34)
            HStack(spacing: 8) {
                Spacer(minLength: 0)
                buttons()
            }
            .frame(height: RecorderLayout.buttonHeight)
        }
    }
}

/// Record screen or Record call: a glyph in a red-tinted circle, what it does, and what it records.
private struct RecordTile: View {
    let symbol: String
    let title: Text
    let detail: Text
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Circle()
                    .fill(RecorderColors.red.opacity(0.2))
                    .overlay {
                        Image(systemName: symbol)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(RecorderColors.red)
                    }
                    .frame(width: 28, height: 28)
                VStack(alignment: .leading, spacing: 2) {
                    title
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.85)
                    detail
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .lineLimit(1)
                .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: RecorderLayout.tileHeight)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(hovering && isEnabled ? 0.12 : 0.07))
            )
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.pressable(.subtle, hoverWash: false))
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : Motion.hover, value: hovering)
    }
}

/// A small switch-like capsule under the tiles: the microphone, the Mac's sound, the display.
private struct RecorderChip: View {
    let symbol: String
    let title: Text
    let on: Bool
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .contentTransition(.symbolEffect(.replace))
                title
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(on ? Color.white : Color.white.opacity(0.45))
            .padding(.horizontal, 9)
            .frame(height: RecorderLayout.chipHeight)
            .background(Capsule().fill(Color.white.opacity(on ? (hovering ? 0.16 : 0.11) : (hovering ? 0.08 : 0.04))))
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable(.normal, hoverWash: false))
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : Motion.hover, value: hovering)
        .animation(reduceMotion ? nil : Motion.snappy, value: on)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// The two sounds being recorded, live: you (the microphone) and the Mac (the other side).
private struct RecorderLevelMeters: View {
    @ObservedObject var levels: RecorderLevels
    let microphone: Bool
    let systemAudio: Bool

    var body: some View {
        HStack(spacing: 12) {
            if microphone { meter("mic.fill", levels.microphone) }
            if systemAudio { meter("speaker.wave.2.fill", levels.system) }
        }
        .accessibilityHidden(true)
    }

    private func meter(_ symbol: String, _ level: Float) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .frame(width: 12)
            LevelMeter(level: Double(level), color: .white, dimmed: false, inset: 0)
                .frame(width: 52)
        }
    }
}

// MARK: - Notices

/// The recorder's notices, below the camera: "Saved" with Show in Finder and Open; a recording
/// that failed; the offer to record a call just joined; the reminder before a first call.
struct RecorderNoticeView: View {
    let notice: RecorderNotice
    let notchSize: CGSize

    @Environment(\.recorder) private var recorder

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchSize.height)
            content
                .padding(.horizontal, IslandLayout.reminderInset)
                .padding(.top, IslandLayout.noticeTopGap)
                .padding(.bottom, IslandLayout.reminderInset)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var content: some View {
        switch notice {
        case .saved(let saved):
            VStack(alignment: .leading, spacing: IslandLayout.reminderRowGap) {
                header(symbol: "checkmark", tint: RecorderColors.green,
                       title: Text("Saved to \(RecorderSettings.breadcrumb(of: saved.url.deletingLastPathComponent()))"),
                       detail: Text(verbatim: "\(saved.kind.title) · \(RecordingClock.format(saved.duration))"))
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    ReminderButton(title: String(localized: "Show in Finder"), symbol: "folder") {
                        recorder?.showInFinder(saved)
                        recorder?.withdrawNotice(notice)
                    }
                    ReminderButton(title: String(localized: "Open"), tint: RecorderColors.blue) {
                        recorder?.open(saved)
                        recorder?.withdrawNotice(notice)
                    }
                }
            }
        case .failed(let message):
            header(symbol: "exclamationmark.triangle.fill", tint: RecorderColors.orange,
                   title: Text("Couldn't record"), detail: Text(message))
        case .offer(let meeting):
            VStack(alignment: .leading, spacing: IslandLayout.reminderRowGap) {
                header(symbol: "record.circle", tint: RecorderColors.red, title: Text("Record this call?"),
                       detail: Text(verbatim: meeting.title.isEmpty ? String(localized: "Meeting") : meeting.title))
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    ReminderButton(title: String(localized: "Not now")) { recorder?.answer(notice, record: false) }
                    ReminderButton(title: String(localized: "Record"), symbol: "record.circle", tint: RecorderColors.red) {
                        recorder?.answer(notice, record: true)
                    }
                }
            }
        case .consent:
            VStack(alignment: .leading, spacing: IslandLayout.reminderRowGap) {
                HStack(spacing: 10) {
                    tile("exclamationmark.bubble.fill", RecorderColors.orange)
                    // One line in English; French and Spanish may take two.
                    Text("Recording laws may require telling everyone on the call.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: RecorderLayout.tileSize)
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    ReminderButton(title: String(localized: "Cancel")) { recorder?.answer(notice, record: false) }
                    ReminderButton(title: String(localized: "Record"), symbol: "record.circle", tint: RecorderColors.red) {
                        recorder?.answer(notice, record: true)
                    }
                }
            }
        }
    }

    private func header(symbol: String, tint: Color, title: Text, detail: Text) -> some View {
        HStack(spacing: 10) {
            tile(symbol, tint)
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                detail
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.5))
            }
            .tracking(-0.2)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: RecorderLayout.tileSize)
        .accessibilityElement(children: .combine)
    }

    private func tile(_ symbol: String, _ tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 9, style: .continuous)
            .fill(tint.opacity(0.22))
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: RecorderLayout.tileSize, height: RecorderLayout.tileSize)
    }
}
