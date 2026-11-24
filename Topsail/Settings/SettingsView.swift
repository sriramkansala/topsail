import SwiftUI

/// Settings: a floating sidebar of panes beside the one chosen. General, the island's activities and
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
            case .island: return "rectangle.topthird.inset.filled"
            case .features: return "switch.2"
            case .integrations: return "puzzlepiece.extension"
            }
        }
    }

    @State private var pane: Pane = .general

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(pane: $pane)
            Group {
                switch pane {
                case .general: GeneralPane(settings: settings)
                case .island: IslandPane(settings: settings, calendar: calendar, clipboard: clipboard)
                case .features: FeaturesPane(settings: settings, features: features, open: { pane = $0 })
                case .integrations: IntegrationsPane(settings: settings, linear: linear, features: features)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(SettingsStyle.background)
        .ignoresSafeArea()
        .frame(minWidth: SettingsStyle.windowSize.width, maxWidth: SettingsStyle.windowSize.width,
               minHeight: SettingsStyle.minimumHeight, maxHeight: SettingsStyle.maximumHeight)
    }
}

// MARK: - General

/// Launch at login, haptics, and about Topsail.
private struct GeneralPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsPage(title: "General", detail: "How Topsail opens and responds.") {
            SettingsSection(note: "Topsail lives in the notch: move the pointer there to open it. Settings is also in the menu bar.") {
                SettingsGroup {
                    SettingsToggle("Launch at login", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { settings.setLaunchAtLogin($0) }
                    ))
                    if settings.launchAtLoginNeedsApproval {
                        SettingsCallout(text: String(localized: "Allow Topsail in System Settings › General › Login Items"),
                                        button: String(localized: "Open Login Items"), action: settings.openLoginItemsSettings)
                    }
                    if let error = settings.launchAtLoginError {
                        SettingsNote(text: Text(error), color: SettingsStyle.destructive)
                            .padding(.top, -SettingsStyle.rowVertical)
                    }
                }
                SettingsToggle("Haptic feedback", detail: String(localized: "A light tap on the trackpad as the island opens."),
                               isOn: $settings.hapticFeedback)
            }

            SettingsSection("About") {
                AboutRow()
            }
        }
    }
}

/// The app's icon, name and version, and where it lives.
private struct AboutRow: View {
    private static let website = URL(string: "https://sriramkansala.github.io/topsail/")!
    private static let repository = URL(string: "https://github.com/sriramkansala/topsail")!
    private static let issues = URL(string: "https://github.com/sriramkansala/topsail/issues")!

    var body: some View {
        VStack(alignment: .leading, spacing: SettingsStyle.rowHorizontal) {
            HStack(spacing: SettingsStyle.rowHorizontal) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 52, height: 52)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SettingsStyle.textGap) {
                    Text(verbatim: "Topsail")
                        .font(SettingsStyle.title)
                        .foregroundStyle(SettingsStyle.foreground)
                    Text("Version \(SettingsView.version)")
                        .font(SettingsStyle.caption)
                        .foregroundStyle(SettingsStyle.muted)
                        .textSelection(.enabled)
                }
            }
            HStack(spacing: 8) {
                Button("Website") { NSWorkspace.shared.open(Self.website) }
                Button { NSWorkspace.shared.open(Self.repository) } label: { Text(verbatim: "GitHub") }
                Button("Report a Problem") { NSWorkspace.shared.open(Self.issues) }
            }
            .buttonStyle(.settings)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SettingsStyle.rowHorizontal)
    }
}

// MARK: - Island

/// What the island shows by itself (live activities) and the pages it opens to.
private struct IslandPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendar: CalendarService
    @ObservedObject var clipboard: ClipboardHistory

    var body: some View {
        SettingsPage(title: "Island", detail: "What shows up in the notch, and the pages it opens to.") {
            SettingsSection("Live activities") {
                SettingsToggle("Now playing", isOn: $settings.showMusicActivity)
                SettingsToggle("Charging and low battery", detail: SettingsView.lowBatteryNote, isOn: $settings.showChargingActivity)
                SettingsToggle("Headphones and speakers", detail: SettingsView.deviceNote, isOn: $settings.showDeviceActivity)
                SettingsToggle("Meeting reminders",
                               detail: String(localized: "A countdown beside the notch, then Join, Ignore or Remind me in 5 min as the call starts."),
                               isOn: $settings.showMeetingReminders)
                SettingsToggle("Linear deadlines", isOn: $settings.showTaskReminders)
                SettingsToggle("Copying", detail: String(localized: "“Copied to clipboard” under the notch; hover it for what you copied."),
                               isOn: $settings.showCopyActivity)
            }

            SettingsSection(SettingsView.soundTitle) {
                SettingsToggle("Volume",
                               detail: settings.hideSystemVolumeHUD ? nil : String(localized: "Appears alongside the system volume indicator."),
                               isOn: $settings.showVolumeActivity)
                #if DIRECT
                SettingsToggle("Brightness",
                               detail: settings.hideSystemVolumeHUD ? nil : String(localized: "Shown while Topsail handles the brightness keys (below)."),
                               isOn: $settings.showBrightnessActivity)
                #endif
                SettingsGroup {
                    SettingsToggle(Text(SettingsView.takeoverTitle), detail: Text(SettingsView.takeoverNote),
                                   isOn: $settings.hideSystemVolumeHUD, icon: { EmptyView() })
                    if settings.hideSystemVolumeHUD && !settings.accessibilityGranted {
                        SettingsCallout(text: String(localized: "Allow Topsail under Privacy & Security › Input Monitoring and Accessibility"),
                                        button: String(localized: "Open System Settings"), action: settings.openKeyAccessSettings)
                    }
                }
            }

            SettingsSection("Pages") {
                SettingsGroup {
                    SettingsToggle("Upcoming events", isOn: $settings.showCalendar)
                    switch calendar.access {
                    case .notDetermined:
                        SettingsCallout(text: String(localized: "Topsail needs access to your calendars"),
                                        button: String(localized: "Allow…"), action: calendar.requestAccess)
                    case .denied:
                        SettingsCallout(text: String(localized: "Allow Topsail under Privacy & Security › Calendars"),
                                        button: String(localized: "Open System Settings"),
                                        action: { SystemSettings.open("Privacy_Calendars") })
                    case .granted:
                        EmptyView()
                    }
                }
                SettingsToggle("Battery and performance", isOn: $settings.showSystemPage)
                SettingsGroup {
                    SettingsToggle("Clipboard history",
                                   detail: String(localized: "The last \(ClipboardHistory.limit) things you copied, kept in memory while Topsail runs; pin one to keep it on this Mac for good. Never sent anywhere, and passwords are skipped."),
                                   isOn: $settings.showClipboard)
                    if settings.showClipboard && clipboard.access != .allowed {
                        SettingsCallout(text: String(localized: "Set Topsail to Always Allow under Privacy & Security › Paste from Other Apps"),
                                        button: clipboard.access == .notDetermined ? String(localized: "Allow…") : String(localized: "Open System Settings"),
                                        action: clipboard.requestAccess)
                    }
                }
            }
        }
    }
}

// MARK: - Features

/// Every switched-off-by-default feature, with what it does; turning one on may ask for a
/// permission or point to its integration.
private struct FeaturesPane: View {
    @ObservedObject var settings: AppSettings
    let features: FeatureServices
    let open: (SettingsView.Pane) -> Void

    var body: some View {
        SettingsPage(title: "Features",
                     detail: "New features start switched off. Each one asks for any permission it needs when you turn it on.") {
            section("In the island", [.shelf, .reminders, .keepAwake, .teleprompter])
            section("With other apps", [.agents, .notifications, .apps])
            section("Updates", [.autoUpdates])
        }
    }

    @ViewBuilder private func section(_ title: LocalizedStringKey, _ group: [Feature]) -> some View {
        let offered = group.filter(Feature.available.contains)
        if !offered.isEmpty {
            SettingsSection(title) {
                ForEach(offered) { feature in
                    SettingsGroup {
                        SettingsToggle(Text(feature.title), detail: Text(feature.summary), isOn: Binding(
                            get: { settings.isEnabled(feature) },
                            set: { on in Motion.perform(Motion.fluidSlow) { settings.setEnabled(feature, on) } }
                        ), icon: { SettingsGlyph(symbol: feature.symbol, lit: settings.isEnabled(feature)) })
                        if settings.isEnabled(feature) {
                            options(for: feature)
                                .transition(.opacity)
                        }
                    }
                }
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
        case .autoUpdates:
            SettingsPanel { UpdateStatus(updater: features.updater) }
        case .notifications:
            SettingsPanel {
                SettingsHintRow(text: Text("Choose apps, and allow Full Disk Access, in Integrations.")) {
                    Button("Integrations…") { open(.integrations) }
                        .buttonStyle(.settings)
                }
            }
        case .agents:
            SettingsPanel {
                SettingsHintRow(text: Text("Connect Claude Code, Codex, Cursor or Antigravity in Integrations.")) {
                    Button("Integrations…") { open(.integrations) }
                        .buttonStyle(.settings)
                }
            }
        case .teleprompter:
            TeleprompterOptions(settings: settings)
        case .keepAwake:
            SettingsPanel {
                SettingsToggle("Keep the display on too", isOn: $settings.keepAwakeDisplay)
                SettingsRow(Text("Turn off after")) {
                    SettingsSelect(label: "Turn off after", selection: $settings.keepAwakeHours,
                                   options: [.init("Never", 0), .init("1 hour", 1), .init("2 hours", 2),
                                             .init("4 hours", 4), .init("8 hours", 8)])
                }
            }
        default:
            EmptyView()
        }
    }
}

/// The script, how fast and how large it runs, and how to start it.
private struct TeleprompterOptions: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsPanel {
            VStack(alignment: .leading, spacing: SettingsStyle.headingGap) {
                Text("Script")
                    .font(SettingsStyle.body)
                    .foregroundStyle(SettingsStyle.foreground)
                SettingsTextEditor(label: "Script", text: $settings.teleprompterScript, height: 112)
            }
            .padding(SettingsStyle.rowVertical)
            SettingsRow(Text("Speed")) {
                HStack(spacing: 8) {
                    // Rounded here rather than with `step`, which draws a tick for every one.
                    Slider(value: Binding(
                        get: { settings.teleprompterSpeed },
                        set: { settings.teleprompterSpeed = ($0 / TeleprompterController.speedStep).rounded() * TeleprompterController.speedStep }
                    ), in: TeleprompterController.speedRange) { Text("Speed") }
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: 160)
                    Text(verbatim: "\(Int(settings.teleprompterSpeed))")
                        .font(SettingsStyle.control.monospacedDigit())
                        .foregroundStyle(SettingsStyle.muted)
                        .frame(width: 28, alignment: .trailing)
                }
            }
            SettingsRow(Text("Text size")) {
                SettingsSelect(label: "Text size", selection: $settings.teleprompterFontSize,
                               options: [.init("Small", 16.0), .init("Medium", 20.0), .init("Large", 26.0)])
            }
            SettingsHintRow(text: Text("Start it from the island's  \(Image(systemName: "text.alignleft"))  button or the menu bar. Space pauses, ↑ ↓ change speed, Esc closes.")) {
                Button("Start") { NotificationCenter.default.post(name: .topsailStartTeleprompter, object: nil) }
                    .buttonStyle(.settings)
            }
        }
    }
}

/// Where automatic updates stand.
private struct UpdateStatus: View {
    @ObservedObject var updater: Updater

    var body: some View {
        SettingsHintRow(text: Text(text)) {
            if case .ready = updater.state {
                Button("Restart to Update") { updater.restartToUpdate() }
                    .buttonStyle(.settings(.primary))
            } else {
                Button("Check Now") { updater.check() }
                    .buttonStyle(.settings)
                    .disabled(updater.state == .checking || updater.state == .developmentBuild)
            }
        }
    }

    private var text: String {
        switch updater.state {
        case .idle: return String(localized: "Version \(SettingsView.version)")
        case .checking: return String(localized: "Checking…")
        case .upToDate: return String(localized: "Topsail is up to date.")
        case .downloading(let version): return String(localized: "Downloading Topsail \(version)…")
        case .ready(let version): return String(localized: "Topsail \(version) installs when Topsail quits.")
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
            SettingsCallout(text: String(localized: "Topsail needs access to your reminders"), button: String(localized: "Allow…"),
                            indented: true, action: reminders.requestAccess)
        case .denied:
            SettingsCallout(text: String(localized: "Allow Topsail under Privacy & Security › Reminders"), button: String(localized: "Open System Settings"),
                            indented: true, action: { SystemSettings.open("Privacy_Reminders") })
        case .granted:
            SettingsPanel {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SettingsStyle.success)
                        .accessibilityHidden(true)
                    Text("Showing your reminders on the calendar tab")
                        .foregroundStyle(SettingsStyle.muted)
                    Spacer(minLength: 0)
                }
                .font(SettingsStyle.caption)
                .padding(SettingsStyle.rowVertical)
            }
        }
    }
}

// MARK: - Integrations

/// The services and apps Topsail connects to.
private struct IntegrationsPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var linear: LinearService
    let features: FeatureServices

    var body: some View {
        SettingsPage(title: "Integrations", detail: "The apps and services Topsail connects to.") {
            #if DIRECT
            AgentsSettingsSection(settings: settings, hub: features.agents)
            NotificationsSettingsSection(settings: settings, mirror: features.notifications)
            SettingsSection("Apps", note: "Shown on the Apps page while these apps are open, and read only while you look. macOS asks once per app. Private Chrome windows are never read. Playing and pausing YouTube needs View › Developer › Allow JavaScript from Apple Events in Chrome.") {
                SettingsToggle("Terminal's last lines", isOn: $settings.appsTerminal)
                SettingsToggle("Chrome's tabs", isOn: $settings.appsChrome)
                SettingsToggle("YouTube in Chrome", isOn: $settings.appsYouTube)
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
        SettingsSection("Notifications", note: "Topsail reads Notification Center's own list on this Mac, only while this is on. Nothing is kept or sent. They also show during a Focus. Full Disk Access is broad: leave this off if you'd rather not grant it.") {
            if settings.isEnabled(.notifications) {
                switch mirror.access {
                case .denied:
                    SettingsCallout(text: String(localized: "Allow Topsail under Privacy & Security › Full Disk Access, then reopen Topsail"),
                                    button: String(localized: "Open System Settings"), action: { SystemSettings.open("Privacy_AllFiles") })
                        .padding(.top, SettingsStyle.rowHorizontal)
                case .unsupported:
                    SettingsNote(text: Text("This version of macOS keeps its notifications in a way Topsail doesn't know yet."),
                                 color: SettingsStyle.warning)
                case .granted, .unknown:
                    EmptyView()
                }
                ForEach(NotificationMirror.installedApps, id: \.self) { app in
                    SettingsToggle(Text(NotificationMirror.name(of: app)), isOn: Binding(
                        get: { settings.notificationApps.contains(app.lowercased()) },
                        set: { on in
                            if on { settings.notificationApps.insert(app.lowercased()) }
                            else { settings.notificationApps.remove(app.lowercased()) }
                        }
                    ), icon: { SettingsAppIcon(bundleID: app) })
                }
                SettingsToggle("Show what they say", isOn: $settings.notificationText)
            } else {
                SettingsRow(Text("Turn on Notifications to choose apps.").foregroundStyle(SettingsStyle.muted)) {
                    Button("Turn On") { settings.setEnabled(.notifications, true) }
                        .buttonStyle(.settings)
                }
            }
        }
    }
}

/// Claude Code, Codex, Cursor and Antigravity: Connect adds Topsail's hook to the agent's own
/// settings (backed up first); what's approved without asking, and how long the notch waits.
private struct AgentsSettingsSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var hub: AgentHub

    /// Bumped after Connect / Disconnect, to re-read the agents' files.
    @State private var revision = 0
    @State private var failure: String?

    var body: some View {
        SettingsSection("AI coding agents", note: "Connect adds Topsail's hook to the agent's own settings file (saving a copy first). If Topsail isn't running or you don't answer in time, the agent asks in its own window as usual. Anything too long to show whole is left to the agent's own window. Cursor can only be denied from outside: Approve lets the command go on to Cursor's own rules.") {
            if !settings.isEnabled(.agents) {
                SettingsRow(Text("Turn on AI coding agents to follow them in the notch.").foregroundStyle(SettingsStyle.muted)) {
                    Button("Turn On") { settings.setEnabled(.agents, true) }
                        .buttonStyle(.settings)
                }
            }
            ForEach(AgentKind.allCases) { agent in
                agentRow(agent, revision: revision)
            }
            if let failure {
                SettingsNote(text: Text(failure), color: SettingsStyle.destructive)
            }
            if let error = hub.serverError {
                SettingsNote(text: Text("Topsail couldn't listen for agents: \(error)"), color: SettingsStyle.destructive)
            }
            SettingsToggle("Approve read-only commands automatically",
                           detail: String(localized: "ls, cat, grep, git status, diff and log, on ordinary files in the project. Hidden files, anything outside the project and names that look like secrets are always asked about."),
                           isOn: $settings.agentsAutoApprove)
            SettingsToggle("Ask me in the notch before other commands", isOn: $settings.agentsAskInNotch)
            SettingsRow(Text("Wait for my answer")) {
                SettingsSelect(label: "Wait for my answer", selection: $settings.agentsWaitSeconds,
                               options: [.init("30 seconds", 30), .init("1 minute", 60), .init("2 minutes", 120)])
            }
            .disabled(!settings.agentsAskInNotch)
            .onChange(of: settings.agentsWaitSeconds) { _, seconds in
                // The hooks' own timeouts follow the wait.
                for agent in AgentKind.allCases where AgentHooks.isConnected(agent) {
                    try? AgentHooks.connect(agent, waitSeconds: seconds)
                }
            }
        }
    }

    private func agentRow(_ agent: AgentKind, revision: Int) -> some View {
        let installed = AgentHooks.isInstalled(agent)
        let connected = AgentHooks.isConnected(agent)
        return SettingsRow(Text(agent.name),
                           detail: Text(connected ? Self.connectedNote(agent) : installed ? String(localized: "Not connected")
                                                                                          : String(localized: "Not found on this Mac")),
                           status: connected ? SettingsStyle.success : nil,
                           icon: { AgentGlyph(agent: agent, size: SettingsStyle.iconSize) }) {
            if connected {
                Button("Disconnect") { run { try AgentHooks.disconnect(agent) } }
                    .buttonStyle(.settings)
            } else {
                Button("Connect") {
                    run { try AgentHooks.connect(agent, waitSeconds: settings.agentsWaitSeconds) }
                    settings.setEnabled(.agents, true)
                }
                .buttonStyle(.settings)
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
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    #if DIRECT
    static let soundTitle: LocalizedStringKey = "Sound and brightness"
    static let takeoverTitle = String(localized: "Hide macOS volume and brightness indicators")
    static let takeoverNote = String(localized: "Topsail handles the volume and brightness keys itself; while Spotify plays on another device, the volume keys control that device. Needs Input Monitoring and Accessibility permission.")
    static let lowBatteryNote = String(localized: "Clicking the low-battery notice turns on Low Power Mode, through a helper you allow once in Login Items.")
    static let deviceNote = String(localized: "A card under the notch with each earbud's and the case's battery; what's playing stays beside it. Asks for Bluetooth access the first time.")
    #else
    static let soundTitle: LocalizedStringKey = "Sound"
    static let takeoverTitle = String(localized: "Hide macOS volume indicator")
    static let takeoverNote = String(localized: "Topsail handles the volume keys itself; while Spotify plays on another device, they control that device. Needs Input Monitoring and Accessibility permission.")
    static let lowBatteryNote = String(localized: "Clicking the low-battery notice opens Battery settings, where you can turn on Low Power Mode.")
    static let deviceNote = String(localized: "A card under the notch with the device's name; what's playing stays beside it.")
    #endif
}

/// Connect a Linear account with a personal API key. The key is checked with Linear before it
/// is kept, and is stored only in the keychain.
private struct LinearSettingsSection: View {
    @ObservedObject var linear: LinearService
    @State private var draftKey = ""

    var body: some View {
        SettingsSection("Linear", note: "Shows your issues in the current cycle (all your open issues if your team has no cycle running), and a reminder when one is due today or overdue. Create a key in Linear under Settings › Security & access › Personal API keys. It is stored in your keychain.") {
            switch linear.status {
            case .connected:
                SettingsRow(Text("Connected"), icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(SettingsStyle.success)
                        .accessibilityHidden(true)
                }) {
                    Button("Disconnect") { linear.disconnect() }
                        .buttonStyle(.settings)
                }
            case .connecting:
                SettingsRow(Text("Checking the key with Linear…").foregroundStyle(SettingsStyle.muted)) {
                    ProgressView().controlSize(.small)
                }
            case .notConnected, .failed:
                SettingsGroup {
                    SettingsRow(Text("Personal API key")) {
                        HStack(spacing: 8) {
                            SettingsSecureField(label: "Personal API key", text: $draftKey, onSubmit: connect)
                                .frame(width: 220)
                            Button("Connect", action: connect)
                                .buttonStyle(.settings(.primary))
                                .disabled(draftKey.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }
                    if case .failed(let message) = linear.status {
                        HStack(spacing: 8) {
                            SettingsNote(text: Text(message), color: SettingsStyle.destructive)
                            if linear.apiKey != nil {
                                Button("Disconnect") { linear.disconnect() }
                                    .buttonStyle(.settings(.ghost))
                                    .padding(.trailing, SettingsStyle.rowHorizontal)
                            }
                        }
                    }
                }
            }
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
        SettingsSection("Voice notes", note: "Press the shortcut or 🎙 in the island, say what changed, then press it again (or ⏎). Transcription and understanding run on this Mac with Apple Intelligence; you review every change in the island before it is sent to Linear. Needs a Linear key with write access.") {
            SettingsRow(Text("Shortcut"), detail: detail, status: linear.isConnected && detail != nil ? SettingsStyle.warning : nil) {
                SettingsSelect(label: "Shortcut", selection: $shortcuts.shortcut,
                               options: VoiceShortcut.allCases.map { .init(LocalizedStringKey($0.title), $0) })
            }
        }
    }

    private var detail: Text? {
        if !linear.isConnected { return Text("Connect Linear above to use voice notes.") }
        if let reason = VoicePlanner.unavailableReason { return Text(reason) }
        if shortcuts.isTaken {
            return Text("Another app already uses \(shortcuts.shortcut.title). Turn it off there or pick a different shortcut.")
        }
        return nil
    }
}
