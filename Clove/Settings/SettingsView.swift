import SwiftUI

/// Settings: a sidebar of panes, as in System Settings. General, the island's activities and
/// pages, the switched-off-by-default features, and the integrations they connect to.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var linear: LinearService
    @ObservedObject var calendar: CalendarService
    @ObservedObject var clipboard: ClipboardHistory
    let features: FeatureServices

    enum Pane: String, CaseIterable, Identifiable {
        case general, island, features, integrations

        var id: String { rawValue }

        var title: LocalizedStringKey {
            switch self {
            case .general: return "General"
            case .island: return "Island"
            case .features: return "Features"
            case .integrations: return "Integrations"
            }
        }

        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .island: return "capsule.portrait"
            case .features: return "square.stack.3d.up"
            case .integrations: return "puzzlepiece.extension"
            }
        }
    }

    @State private var pane: Pane? = .general

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $pane) { pane in
                Label(pane.title, systemImage: pane.symbol)
                    .tag(pane)
            }
            .navigationSplitViewColumnWidth(170)
        } detail: {
            Group {
                switch pane ?? .general {
                case .general: GeneralPane(settings: settings)
                case .island: IslandPane(settings: settings, calendar: calendar, clipboard: clipboard)
                case .features: FeaturesPane(settings: settings, features: features, open: { pane = $0 })
                case .integrations: IntegrationsPane(settings: settings, linear: linear)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 700, height: 580)
    }
}

/// Launch at login, haptics, and where to find Clove.
private struct GeneralPane: View {
    @ObservedObject var settings: AppSettings

    private var versionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(
                        "Launch at login",
                        isOn: Binding(
                            get: { settings.launchAtLogin },
                            set: { settings.setLaunchAtLogin($0) }
                        )
                    )
                    if settings.launchAtLoginNeedsApproval {
                        PermissionHint(text: "Allow Clove in System Settings › General › Login Items",
                                       button: "Open Login Items", action: settings.openLoginItemsSettings)
                    }
                    if let error = settings.launchAtLoginError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                Toggle("Haptic feedback", isOn: $settings.hapticFeedback)
            } footer: {
                Text("Clove lives in the notch: move the pointer there to open it. Settings is also in the menu bar.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                Text("Clove \(versionString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }
}

/// What the island shows by itself (live activities) and the pages it opens to.
private struct IslandPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendar: CalendarService
    @ObservedObject var clipboard: ClipboardHistory

    var body: some View {
        Form {
            Section("Live activities") {
                Toggle("Now playing", isOn: $settings.showMusicActivity)
                Captioned(caption: SettingsView.lowBatteryNote) {
                    Toggle("Charging and low battery", isOn: $settings.showChargingActivity)
                }
                Captioned(caption: SettingsView.deviceNote) {
                    Toggle("Headphones and speakers", isOn: $settings.showDeviceActivity)
                }
                Captioned(caption: "A countdown beside the notch, then Join, Ignore or Remind me in 5 min as the call starts.") {
                    Toggle("Meeting reminders", isOn: $settings.showMeetingReminders)
                }
                Toggle("Linear deadlines", isOn: $settings.showTaskReminders)
                Captioned(caption: "“Copied to clipboard” under the notch; hover it for what you copied.") {
                    Toggle("Copying", isOn: $settings.showCopyActivity)
                }

                Captioned(caption: settings.hideSystemVolumeHUD ? nil : "Appears alongside the system volume indicator.") {
                    Toggle("Volume", isOn: $settings.showVolumeActivity)
                }

                #if DIRECT
                Captioned(caption: settings.hideSystemVolumeHUD ? nil : "Shown while Clove handles the brightness keys (below).") {
                    Toggle("Brightness", isOn: $settings.showBrightnessActivity)
                }
                #endif

                VStack(alignment: .leading, spacing: 2) {
                    Toggle(SettingsView.takeoverTitle, isOn: $settings.hideSystemVolumeHUD)
                    Text(SettingsView.takeoverNote)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if settings.hideSystemVolumeHUD && !settings.accessibilityGranted {
                        PermissionHint(text: "Allow Clove under Privacy & Security › Input Monitoring and Accessibility",
                                       button: "Open System Settings", action: settings.openKeyAccessSettings)
                    }
                }
            }

            Section("Pages") {
                VStack(alignment: .leading, spacing: 2) {
                    Toggle("Upcoming events", isOn: $settings.showCalendar)
                    switch calendar.access {
                    case .notDetermined:
                        PermissionHint(text: "Clove needs access to your calendars",
                                       button: "Allow…", action: calendar.requestAccess)
                    case .denied:
                        PermissionHint(text: "Allow Clove under Privacy & Security › Calendars",
                                       button: "Open System Settings",
                                       action: { SystemSettings.open("Privacy_Calendars") })
                    case .granted:
                        EmptyView()
                    }
                }
                Toggle("Battery and performance", isOn: $settings.showSystemPage)
                VStack(alignment: .leading, spacing: 2) {
                    Toggle("Clipboard history", isOn: $settings.showClipboard)
                    Text("The last \(ClipboardHistory.limit) things you copied, kept in memory while Clove runs; pin one to keep it on this Mac for good. Never sent anywhere, and passwords are skipped.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if settings.showClipboard && clipboard.access != .allowed {
                        PermissionHint(text: "Set Clove to Always Allow under Privacy & Security › Paste from Other Apps",
                                       button: clipboard.access == .notDetermined ? "Allow…" : "Open System Settings",
                                       action: clipboard.requestAccess)
                    }
                }
            }
        }
    }
}

/// Every switched-off-by-default feature, with what it does; turning one on may ask for a
/// permission or point to its integration.
private struct FeaturesPane: View {
    @ObservedObject var settings: AppSettings
    let features: FeatureServices
    let open: (SettingsView.Pane) -> Void

    var body: some View {
        Form {
            Section {
                ForEach(Feature.available) { feature in
                    FeatureRow(feature: feature, isOn: Binding(
                        get: { settings.isEnabled(feature) },
                        set: { settings.setEnabled(feature, $0) }
                    ))
                    if settings.isEnabled(feature) {
                        options(for: feature)
                    }
                }
            } footer: {
                Text("New features start switched off. Each one asks for any permission it needs when you turn it on.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

extension FeaturesPane {
    /// What a feature that's on can be set to, under its row.
    @ViewBuilder func options(for feature: Feature) -> some View {
        switch feature {
        case .keepAwake:
            Toggle("Keep the display on too", isOn: $settings.keepAwakeDisplay)
                .padding(.leading, 40)
            Picker("Turn off after", selection: $settings.keepAwakeHours) {
                Text("Never").tag(0)
                Text("1 hour").tag(1)
                Text("2 hours").tag(2)
                Text("4 hours").tag(4)
                Text("8 hours").tag(8)
            }
            .padding(.leading, 40)
        default:
            EmptyView()
        }
    }
}

/// One feature: its symbol, name and what it does, and its switch.
private struct FeatureRow: View {
    let feature: Feature
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.accentColor.opacity(isOn ? 1 : 0.15))
                .overlay {
                    Image(systemName: feature.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isOn ? .white : .accentColor)
                }
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                Text(feature.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Toggle(feature.title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .padding(.vertical, 2)
    }
}

/// The services Clove connects to: Linear and voice notes so far.
private struct IntegrationsPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var linear: LinearService

    var body: some View {
        Form {
            LinearSettingsSection(linear: linear)
            VoiceSettingsSection(linear: linear)
        }
    }
}

/// Opens a pane of System Settings › Privacy & Security.
enum SystemSettings {
    static func open(_ anchor: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }
}

private extension SettingsView {
    #if DIRECT
    static let takeoverTitle = "Hide macOS volume and brightness indicators"
    static let takeoverNote = "Clove handles the volume and brightness keys itself; while Spotify plays on another device, the volume keys control that device. Needs Input Monitoring and Accessibility permission."
    static let lowBatteryNote = "Clicking the low-battery notice turns on Low Power Mode, through a helper you allow once in Login Items."
    static let deviceNote = "A card under the notch with each earbud's and the case's battery; what's playing stays beside it. Asks for Bluetooth access the first time."
    #else
    static let takeoverTitle = "Hide macOS volume indicator"
    static let takeoverNote = "Clove handles the volume keys itself; while Spotify plays on another device, they control that device. Needs Input Monitoring and Accessibility permission."
    static let lowBatteryNote = "Clicking the low-battery notice opens Battery settings, where you can turn on Low Power Mode."
    static let deviceNote = "A card under the notch with the device's name; what's playing stays beside it."
    #endif
}

/// A control with an optional caption under it, in one row.
struct Captioned<Content: View>: View {
    let caption: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            content
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Something Clove is missing a permission for, and the button that fixes it.
struct PermissionHint: View {
    let text: String
    let button: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.caption)
                .foregroundColor(.orange)
            Spacer()
            Button(button, action: action)
                .controlSize(.small)
        }
    }
}

/// Connect a Linear account with a personal API key. The key is checked with Linear before it
/// is kept, and is stored only in the keychain.
private struct LinearSettingsSection: View {
    @ObservedObject var linear: LinearService
    @State private var draftKey = ""

    var body: some View {
        Section {
            switch linear.status {
            case .connected:
                HStack {
                    Label("Connected", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Spacer()
                    Button("Disconnect") { linear.disconnect() }
                }
            case .connecting:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Checking the key with Linear…")
                        .foregroundColor(.secondary)
                }
            case .notConnected, .failed:
                HStack {
                    SecureField("Personal API key", text: $draftKey)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(connect)
                    Button("Connect", action: connect)
                        .disabled(draftKey.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if case .failed(let message) = linear.status {
                    HStack(spacing: 8) {
                        Text(message)
                            .font(.caption)
                            .foregroundColor(.red)
                        if linear.apiKey != nil {
                            Spacer()
                            Button("Disconnect") { linear.disconnect() }
                                .controlSize(.small)
                        }
                    }
                }
            }
        } header: {
            Text("Linear")
        } footer: {
            Text("Shows your issues in the current cycle (all your open issues if your team has no cycle running), and a reminder when one is due today or overdue. Create a key in Linear under Settings › Security & access › Personal API keys. It is stored in your keychain.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func connect() {
        linear.connect(apiKey: draftKey)
        draftKey = ""
    }
}

/// The voice-note shortcut. Notes are recorded, transcribed and understood on this Mac, then
/// reviewed in the island before anything is sent to Linear.
private struct VoiceSettingsSection: View {
    @ObservedObject var linear: LinearService
    @ObservedObject private var shortcuts = VoiceShortcutManager.shared

    var body: some View {
        Section {
            Picker("Shortcut", selection: $shortcuts.shortcut) {
                ForEach(VoiceShortcut.allCases) { shortcut in
                    Text(shortcut.title).tag(shortcut)
                }
            }
            if !linear.isConnected {
                Text("Connect Linear above to use voice notes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let reason = VoicePlanner.unavailableReason {
                Text(reason)
                    .font(.caption)
                    .foregroundColor(.orange)
            } else if shortcuts.isTaken {
                Text("Another app already uses \(shortcuts.shortcut.title). Turn it off there or pick a different shortcut.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        } header: {
            Text("Voice notes")
        } footer: {
            Text("Press the shortcut or 🎙 in the island, say what changed, then press it again (or ⏎). Transcription and understanding run on this Mac with Apple Intelligence; you review every change in the island before it is sent to Linear. Needs a Linear key with write access.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
