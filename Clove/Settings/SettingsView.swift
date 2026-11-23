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
                case .integrations: IntegrationsPane(settings: settings, linear: linear, features: features,
                                                     open: { pane = $0 })
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
                        PermissionHint(text: String(localized: "Allow Clove in System Settings › General › Login Items"),
                                       button: String(localized: "Open Login Items"), action: settings.openLoginItemsSettings)
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
                Captioned(caption: String(localized: "A countdown beside the notch, then Join, Ignore or Remind me in 5 min as the call starts.")) {
                    Toggle("Meeting reminders", isOn: $settings.showMeetingReminders)
                }
                Toggle("Linear deadlines", isOn: $settings.showTaskReminders)
                Captioned(caption: String(localized: "“Copied to clipboard” under the notch; hover it for what you copied.")) {
                    Toggle("Copying", isOn: $settings.showCopyActivity)
                }

                Captioned(caption: settings.hideSystemVolumeHUD ? nil : String(localized: "Appears alongside the system volume indicator.")) {
                    Toggle("Volume", isOn: $settings.showVolumeActivity)
                }

                #if DIRECT
                Captioned(caption: settings.hideSystemVolumeHUD ? nil : String(localized: "Shown while Clove handles the brightness keys (below).")) {
                    Toggle("Brightness", isOn: $settings.showBrightnessActivity)
                }
                #endif

                VStack(alignment: .leading, spacing: 2) {
                    Toggle(SettingsView.takeoverTitle, isOn: $settings.hideSystemVolumeHUD)
                    Text(SettingsView.takeoverNote)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if settings.hideSystemVolumeHUD && !settings.accessibilityGranted {
                        PermissionHint(text: String(localized: "Allow Clove under Privacy & Security › Input Monitoring and Accessibility"),
                                       button: String(localized: "Open System Settings"), action: settings.openKeyAccessSettings)
                    }
                }
            }

            Section("Pages") {
                VStack(alignment: .leading, spacing: 2) {
                    Toggle("Upcoming events", isOn: $settings.showCalendar)
                    switch calendar.access {
                    case .notDetermined:
                        PermissionHint(text: String(localized: "Clove needs access to your calendars"),
                                       button: String(localized: "Allow…"), action: calendar.requestAccess)
                    case .denied:
                        PermissionHint(text: String(localized: "Allow Clove under Privacy & Security › Calendars"),
                                       button: String(localized: "Open System Settings"),
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
                        PermissionHint(text: String(localized: "Set Clove to Always Allow under Privacy & Security › Paste from Other Apps"),
                                       button: clipboard.access == .notDetermined ? String(localized: "Allow…") : String(localized: "Open System Settings"),
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
        case .reminders:
            RemindersAccessHint(reminders: features.reminders)
                .padding(.leading, 40)
        case .autoUpdates:
            UpdateStatus(updater: features.updater)
                .padding(.leading, 40)
        case .notifications:
            HStack {
                Text("Choose apps, and allow Full Disk Access, in Integrations.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Integrations…") { open(.integrations) }
            }
            .padding(.leading, 40)
        case .agents:
            HStack {
                Text("Connect Claude Code, Codex, Cursor or Antigravity in Integrations.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Integrations…") { open(.integrations) }
            }
            .padding(.leading, 40)
        case .teleprompter:
            VStack(alignment: .leading, spacing: 6) {
                Text("Script")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $settings.teleprompterScript)
                    .font(.system(size: 13))
                    .frame(height: 140)
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(nsColor: .textBackgroundColor)))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.3)))
            }
            .padding(.leading, 40)
            HStack {
                Text("Speed")
                Slider(value: $settings.teleprompterSpeed, in: TeleprompterController.speedRange,
                       step: TeleprompterController.speedStep)
                Text("\(Int(settings.teleprompterSpeed))")
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
            .padding(.leading, 40)
            Picker("Text size", selection: $settings.teleprompterFontSize) {
                Text("Small").tag(16.0)
                Text("Medium").tag(20.0)
                Text("Large").tag(26.0)
            }
            .padding(.leading, 40)
            HStack {
                Text("Start it from the island's  \(Image(systemName: "text.alignleft"))  button or the menu bar. Space pauses, ↑ ↓ change speed, Esc closes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Start") { NotificationCenter.default.post(name: .cloveStartTeleprompter, object: nil) }
            }
            .padding(.leading, 40)
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

/// Where automatic updates stand.
private struct UpdateStatus: View {
    @ObservedObject var updater: Updater

    var body: some View {
        HStack {
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            if case .ready = updater.state {
                Button("Restart to Update") { updater.restartToUpdate() }
            } else {
                Button("Check Now") { updater.check() }
                    .disabled(updater.state == .checking || updater.state == .developmentBuild)
            }
        }
    }

    private var text: String {
        switch updater.state {
        case .idle: return ""
        case .checking: return String(localized: "Checking…")
        case .upToDate: return String(localized: "Clove is up to date.")
        case .downloading(let version): return String(localized: "Downloading Clove \(version)…")
        case .ready(let version): return String(localized: "Clove \(version) installs when Clove quits.")
        case .failed(let message): return message
        case .developmentBuild: return String(localized: "This is a development build, which doesn't update itself.")
        }
    }
}

/// Reminders needs access to the Reminders app's lists.
private struct RemindersAccessHint: View {
    @ObservedObject var reminders: RemindersService

    var body: some View {
        switch reminders.access {
        case .notDetermined:
            PermissionHint(text: String(localized: "Clove needs access to your reminders"), button: String(localized: "Allow…"),
                           action: reminders.requestAccess)
        case .denied:
            PermissionHint(text: String(localized: "Allow Clove under Privacy & Security › Reminders"), button: String(localized: "Open System Settings"),
                           action: { SystemSettings.open("Privacy_Reminders") })
        case .granted:
            Label("Showing your reminders on the calendar tab", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.secondary)
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

/// The services and apps Clove connects to.
private struct IntegrationsPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var linear: LinearService
    let features: FeatureServices
    let open: (SettingsView.Pane) -> Void

    var body: some View {
        Form {
            #if DIRECT
            AgentsSettingsSection(settings: settings, hub: features.agents, open: open)
            NotificationsSettingsSection(settings: settings, mirror: features.notifications)
            Section {
                Toggle("Terminal's last lines", isOn: $settings.appsTerminal)
                Toggle("Chrome's tabs", isOn: $settings.appsChrome)
                Toggle("YouTube in Chrome", isOn: $settings.appsYouTube)
            } header: {
                Text("Apps")
            } footer: {
                Text("Shown on the Apps page while these apps are open, and read only while you look. macOS asks once per app. Private Chrome windows are never read. Playing and pausing YouTube needs View › Developer › Allow JavaScript from Apple Events in Chrome.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            #endif
            LinearSettingsSection(linear: linear)
            VoiceSettingsSection(linear: linear)
        }
    }
}

#if DIRECT
/// Which apps' notifications slide out of the notch, and the access that takes.
private struct NotificationsSettingsSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var mirror: NotificationMirror

    var body: some View {
        Section {
            if settings.isEnabled(.notifications) {
                switch mirror.access {
                case .denied:
                    PermissionHint(text: String(localized: "Allow Clove under Privacy & Security › Full Disk Access, then reopen Clove"),
                                   button: String(localized: "Open System Settings"), action: { SystemSettings.open("Privacy_AllFiles") })
                case .unsupported:
                    Text("This version of macOS keeps its notifications in a way Clove doesn't know yet.")
                        .font(.caption)
                        .foregroundColor(.orange)
                case .granted, .unknown:
                    EmptyView()
                }
                ForEach(NotificationMirror.installedApps, id: \.self) { app in
                    Toggle(NotificationMirror.name(of: app), isOn: Binding(
                        get: { settings.notificationApps.contains(app.lowercased()) },
                        set: { on in
                            if on { settings.notificationApps.insert(app.lowercased()) }
                            else { settings.notificationApps.remove(app.lowercased()) }
                        }
                    ))
                }
                Toggle("Show what they say", isOn: $settings.notificationText)
            } else {
                HStack {
                    Text("Turn on Notifications to choose apps.")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Turn On") { settings.setEnabled(.notifications, true) }
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Clove reads Notification Center's own list on this Mac, only while this is on. Nothing is kept or sent. They also show during a Focus. Full Disk Access is broad: leave this off if you'd rather not grant it.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

/// Claude Code, Codex, Cursor and Antigravity: Connect adds Clove's hook to the agent's own
/// settings (backed up first); what's approved without asking, and how long the notch waits.
private struct AgentsSettingsSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var hub: AgentHub
    let open: (SettingsView.Pane) -> Void

    /// Bumped after Connect / Disconnect, to re-read the agents' files.
    @State private var revision = 0
    @State private var failure: String?

    var body: some View {
        Section {
            if !settings.isEnabled(.agents) {
                HStack {
                    Text("Turn on AI coding agents to follow them in the notch.")
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Turn On") { settings.setEnabled(.agents, true) }
                }
            }
            ForEach(AgentKind.allCases) { agent in
                agentRow(agent)
            }
            .id(revision)
            if let failure {
                Text(failure)
                    .font(.caption)
                    .foregroundColor(.red)
            }
            if let error = hub.serverError {
                Text("Clove couldn't listen for agents: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            Captioned(caption: String(localized: "ls, cat, grep, git status, diff and log, on ordinary files in the project. Hidden files, anything outside the project and names that look like secrets are always asked about.")) {
                Toggle("Approve read-only commands automatically", isOn: $settings.agentsAutoApprove)
            }
            Toggle("Ask me in the notch before other commands", isOn: $settings.agentsAskInNotch)
            Picker("Wait for my answer", selection: $settings.agentsWaitSeconds) {
                Text("30 seconds").tag(30)
                Text("1 minute").tag(60)
                Text("2 minutes").tag(120)
            }
            .disabled(!settings.agentsAskInNotch)
            .onChange(of: settings.agentsWaitSeconds) { _, seconds in
                // The hooks' own timeouts follow the wait.
                for agent in AgentKind.allCases where AgentHooks.isConnected(agent) {
                    try? AgentHooks.connect(agent, waitSeconds: seconds)
                }
            }
        } header: {
            Text("AI coding agents")
        } footer: {
            Text("Connect adds Clove's hook to the agent's own settings file (saving a copy first). If Clove isn't running or you don't answer in time, the agent asks in its own window as usual. Anything too long to show whole is left to the agent's own window. Cursor can only be denied from outside: Approve lets the command go on to Cursor's own rules.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder private func agentRow(_ agent: AgentKind) -> some View {
        let installed = AgentHooks.isInstalled(agent)
        let connected = AgentHooks.isConnected(agent)
        HStack(spacing: 10) {
            AgentGlyph(agent: agent, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(agent.name)
                Text(connected ? Self.connectedNote(agent) : installed ? String(localized: "Not connected")
                                                                       : String(localized: "Not found on this Mac"))
                    .font(.caption)
                    .foregroundColor(connected ? .green : .secondary)
            }
            Spacer()
            if connected {
                Button("Disconnect") { run { try AgentHooks.disconnect(agent) } }
            } else {
                Button("Connect") {
                    run { try AgentHooks.connect(agent, waitSeconds: settings.agentsWaitSeconds) }
                    settings.setEnabled(.agents, true)
                }
                .disabled(!installed)
            }
        }
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
        revision += 1
    }

    /// What connecting takes, per agent.
    static func connectedNote(_ agent: AgentKind) -> String {
        switch agent {
        case .claude: return String(localized: "Connected · applies to new sessions")
        case .codex: return String(localized: "Connected · run /hooks in Codex once to trust it")
        case .cursor: return String(localized: "Connected · restart Cursor to load it")
        case .antigravity: return String(localized: "Connected · the CLI runs it; the IDE may not yet")
        }
    }
}
#endif

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
    static let takeoverTitle = String(localized: "Hide macOS volume and brightness indicators")
    static let takeoverNote = String(localized: "Clove handles the volume and brightness keys itself; while Spotify plays on another device, the volume keys control that device. Needs Input Monitoring and Accessibility permission.")
    static let lowBatteryNote = String(localized: "Clicking the low-battery notice turns on Low Power Mode, through a helper you allow once in Login Items.")
    static let deviceNote = String(localized: "A card under the notch with each earbud's and the case's battery; what's playing stays beside it. Asks for Bluetooth access the first time.")
    #else
    static let takeoverTitle = String(localized: "Hide macOS volume indicator")
    static let takeoverNote = String(localized: "Clove handles the volume keys itself; while Spotify plays on another device, they control that device. Needs Input Monitoring and Accessibility permission.")
    static let lowBatteryNote = String(localized: "Clicking the low-battery notice opens Battery settings, where you can turn on Low Power Mode.")
    static let deviceNote = String(localized: "A card under the notch with the device's name; what's playing stays beside it.")
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
