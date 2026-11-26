import AppKit
import AVFoundation
import SwiftUI

/// Settings › Features › Screen and call recorder, under its switch: the permissions it still
/// needs, where recordings go, in what format, and with which sounds.
struct RecorderOptions: View {
    @ObservedObject var settings: RecorderSettings

    var body: some View {
        RecorderPermissionHints(microphone: settings.microphone)
        SettingsPanel {
            SettingsRow(Text("Save to"), detail: Text(verbatim: settings.folderDisplayPath)) {
                HStack(spacing: 8) {
                    if !settings.isDefaultFolder {
                        Button("Reset") { settings.resetFolder() }
                            .buttonStyle(.settings(.ghost))
                    }
                    Button("Show") { settings.showFolder() }
                        .buttonStyle(.settings)
                    Button("Choose…") { settings.chooseFolder(in: NSApp.keyWindow) }
                        .buttonStyle(.settings)
                }
            }
            SettingsRow(Text("Screen recordings"), detail: Text("Calls are saved as .m4a audio.")) {
                SettingsSelect(label: "Screen recordings", selection: $settings.format,
                               options: [.init("QuickTime movie (.mov)", .mov), .init("MPEG-4 (.mp4)", .mp4)])
            }
            SettingsToggle("Microphone",
                           detail: String(localized: "Your voice, with the screen and as your side of a call."),
                           isOn: $settings.microphone)
            SettingsToggle("Mac sound",
                           detail: String(localized: "What your Mac plays, and the other side of a call."),
                           isOn: $settings.systemAudio)
            SettingsToggle("Separate tracks", detail: Self.tracksNote, isOn: $settings.separateTracks)
            SettingsToggle("Offer to record calls",
                           detail: String(localized: "After you join a call from the meeting reminder. It never records by itself."),
                           isOn: $settings.offerForCalls)
            SettingsToggle("Show the island in screen recordings", isOn: $settings.showsIsland)
        }
    }

    private static var tracksNote: String {
        if #available(macOS 27.0, *) {
            return String(localized: "Your voice and the Mac's sound stay apart, for editing. Off, they're mixed into one track.")
        }
        return String(localized: "Your voice and the Mac's sound stay apart in calls, for editing. Screen recordings are mixed until macOS 27.")
    }
}

/// Screen Recording (which also covers the Mac's sound) and the microphone: what's missing, and
/// the button that asks, or opens the right list in System Settings. Topsail never changes them.
private struct RecorderPermissionHints: View {
    let microphone: Bool

    @State private var screen = CGPreflightScreenCaptureAccess()
    @State private var mic = AVCaptureDevice.authorizationStatus(for: .audio)
    /// Asked once already: macOS won't ask again, so the button opens System Settings instead.
    @AppStorage("recorder.askedForScreen") private var askedForScreen = false

    var body: some View {
        Group {
            if !screen {
                SettingsCallout(text: String(localized: "Allow Topsail under Privacy & Security › Screen & System Audio Recording"),
                                button: askedForScreen ? String(localized: "Open System Settings") : String(localized: "Allow…"),
                                indented: true) {
                    if askedForScreen {
                        SystemSettings.open("Privacy_ScreenCapture")
                    } else {
                        askedForScreen = true
                        screen = CGRequestScreenCaptureAccess()
                    }
                }
            }
            if microphone {
                switch mic {
                case .notDetermined:
                    SettingsCallout(text: String(localized: "Topsail needs the microphone to record your voice"),
                                    button: String(localized: "Allow…"), indented: true) {
                        Task {
                            _ = await AVCaptureDevice.requestAccess(for: .audio)
                            mic = AVCaptureDevice.authorizationStatus(for: .audio)
                        }
                    }
                case .denied, .restricted:
                    SettingsCallout(text: String(localized: "Allow Topsail under Privacy & Security › Microphone"),
                                    button: String(localized: "Open System Settings"), indented: true) {
                        SystemSettings.open("Privacy_Microphone")
                    }
                default:
                    EmptyView()
                }
            }
        }
        // Permissions change in System Settings while this is open.
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }

    private func refresh() {
        let screen = CGPreflightScreenCaptureAccess()
        if screen != self.screen { self.screen = screen }
        let mic = AVCaptureDevice.authorizationStatus(for: .audio)
        if mic != self.mic { self.mic = mic }
    }
}
