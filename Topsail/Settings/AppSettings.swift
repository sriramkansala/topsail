import AppKit
import Combine
import CoreGraphics
import ServiceManagement

/// User preferences, persisted in UserDefaults. Launch at login is read from and written to
/// `SMAppService.mainApp` directly, so it always reflects System Settings > Login Items.
@MainActor
final class AppSettings: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var showMusicActivity: Bool { didSet { save(showMusicActivity, "showMusicActivity") } }
    @Published var showChargingActivity: Bool { didSet { save(showChargingActivity, "showChargingActivity") } }
    @Published var showDeviceActivity: Bool { didSet { save(showDeviceActivity, "showDeviceActivity") } }
    @Published var showVolumeActivity: Bool { didSet { save(showVolumeActivity, "showVolumeActivity") } }
    /// Direct-download build only; the App Store build cannot change brightness.
    @Published var showBrightnessActivity: Bool { didSet { save(showBrightnessActivity, "showBrightnessActivity") } }
    /// "Meeting in 10 min" beside the notch before a calendar event with a video link, and the
    /// Join / Ignore / Remind me card as it starts.
    @Published var showMeetingReminders: Bool { didSet { save(showMeetingReminders, "showMeetingReminders") } }
    /// A short notice when a Linear issue is due today or overdue.
    @Published var showTaskReminders: Bool { didSet { save(showTaskReminders, "showTaskReminders") } }
    @Published var showCalendar: Bool { didSet { save(showCalendar, "showCalendar") } }
    @Published var showSystemPage: Bool { didSet { save(showSystemPage, "showSystemPage") } }
    /// The clipboard page: what you copy, kept in memory while Topsail runs.
    @Published var showClipboard: Bool { didSet { save(showClipboard, "showClipboard") } }
    /// "Copied to clipboard" under the notch on every copy.
    @Published var showCopyActivity: Bool { didSet { save(showCopyActivity, "showCopyActivity") } }
    @Published var hapticFeedback: Bool { didSet { save(hapticFeedback, "hapticFeedback") } }
    /// Keep Awake also keeps the display on.
    @Published var keepAwakeDisplay: Bool { didSet { save(keepAwakeDisplay, "keepAwakeDisplay") } }
    /// Keep Awake turns itself off after this many hours; 0 = when turned off.
    @Published var keepAwakeHours: Int { didSet { defaults.set(keepAwakeHours, forKey: "keepAwakeHours") } }
    /// The teleprompter's script, its speed (points a second) and text size.
    @Published var teleprompterScript: String { didSet { defaults.set(teleprompterScript, forKey: "teleprompterScript") } }
    @Published var teleprompterSpeed: Double { didSet { defaults.set(teleprompterSpeed, forKey: "teleprompterSpeed") } }
    @Published var teleprompterFontSize: Double { didSet { defaults.set(teleprompterFontSize, forKey: "teleprompterFontSize") } }
    /// AI agents: read-only commands are approved without asking; other commands ask in the notch,
    /// for this long, before the agent asks in its own window.
    @Published var agentsAutoApprove: Bool { didSet { save(agentsAutoApprove, "agentsAutoApprove") } }
    @Published var agentsAskInNotch: Bool { didSet { save(agentsAskInNotch, "agentsAskInNotch") } }
    @Published var agentsWaitSeconds: Int { didSet { defaults.set(agentsWaitSeconds, forKey: "agentsWaitSeconds") } }
    /// Notifications: the apps shown (lower-case bundle identifiers), and whether with their text.
    @Published var notificationApps: Set<String> { didSet { defaults.set(notificationApps.sorted(), forKey: "notificationApps") } }
    @Published var notificationText: Bool { didSet { save(notificationText, "notificationText") } }
    /// The Apps page's parts.
    @Published var appsTerminal: Bool { didSet { save(appsTerminal, "appsTerminal") } }
    @Published var appsChrome: Bool { didSet { save(appsChrome, "appsChrome") } }
    @Published var appsYouTube: Bool { didSet { save(appsYouTube, "appsYouTube") } }
    /// Which of the switched-off-by-default features are on (Settings › Features).
    @Published private(set) var features: Set<Feature> = []
    /// Take over the volume keys so macOS hides its own volume indicator (needs Input Monitoring
    /// and Accessibility).
    @Published var hideSystemVolumeHUD: Bool { didSet { save(hideSystemVolumeHUD, "hideSystemVolumeHUD") } }
    /// Whether Topsail may filter keyboard events — Input Monitoring and Accessibility in System
    /// Settings.
    @Published private(set) var accessibilityGranted = CGPreflightPostEventAccess()

    @Published private(set) var launchAtLogin: Bool
    /// The login item is registered but waits for the user to allow it in System Settings.
    @Published private(set) var launchAtLoginNeedsApproval = false
    /// Set when registering or unregistering the login item fails; shown under the toggle.
    @Published private(set) var launchAtLoginError: String?

    init() {
        defaults.register(defaults: [
            "showMusicActivity": true,
            "showChargingActivity": true,
            "showDeviceActivity": true,
            "showVolumeActivity": true,
            "showBrightnessActivity": true,
            "showMeetingReminders": true,
            "showTaskReminders": true,
            "showCalendar": true,
            "showSystemPage": true,
            "showClipboard": true,
            "showCopyActivity": true,
            "hapticFeedback": true,
            "keepAwakeDisplay": false,
            "keepAwakeHours": 0,
            "notificationApps": ["com.apple.mobilesms", "com.apple.mail", "com.tinyspeck.slackmacgap", "com.hnc.discord",
                                 "com.burbn.instagram"],
            "appsTerminal": true,
            "appsChrome": true,
            "appsYouTube": true,
            "notificationText": true,
            "agentsAutoApprove": true,
            "agentsAskInNotch": true,
            "agentsWaitSeconds": 60,
            "teleprompterScript": "",
            "teleprompterSpeed": 40.0,
            "teleprompterFontSize": 20.0,
            "hideSystemVolumeHUD": Self.takesOverKeysByDefault,
        ])
        showMusicActivity = defaults.bool(forKey: "showMusicActivity")
        showChargingActivity = defaults.bool(forKey: "showChargingActivity")
        showDeviceActivity = defaults.bool(forKey: "showDeviceActivity")
        showVolumeActivity = defaults.bool(forKey: "showVolumeActivity")
        showBrightnessActivity = defaults.bool(forKey: "showBrightnessActivity")
        showMeetingReminders = defaults.bool(forKey: "showMeetingReminders")
        showTaskReminders = defaults.bool(forKey: "showTaskReminders")
        showCalendar = defaults.bool(forKey: "showCalendar")
        showSystemPage = defaults.bool(forKey: "showSystemPage")
        showClipboard = defaults.bool(forKey: "showClipboard")
        showCopyActivity = defaults.bool(forKey: "showCopyActivity")
        hapticFeedback = defaults.bool(forKey: "hapticFeedback")
        hideSystemVolumeHUD = defaults.bool(forKey: "hideSystemVolumeHUD")
        keepAwakeDisplay = defaults.bool(forKey: "keepAwakeDisplay")
        keepAwakeHours = defaults.integer(forKey: "keepAwakeHours")
        notificationApps = Set(defaults.stringArray(forKey: "notificationApps") ?? [])
        appsTerminal = defaults.bool(forKey: "appsTerminal")
        appsChrome = defaults.bool(forKey: "appsChrome")
        appsYouTube = defaults.bool(forKey: "appsYouTube")
        notificationText = defaults.bool(forKey: "notificationText")
        agentsAutoApprove = defaults.bool(forKey: "agentsAutoApprove")
        agentsAskInNotch = defaults.bool(forKey: "agentsAskInNotch")
        agentsWaitSeconds = defaults.integer(forKey: "agentsWaitSeconds")
        teleprompterScript = defaults.string(forKey: "teleprompterScript") ?? ""
        teleprompterSpeed = defaults.double(forKey: "teleprompterSpeed")
        teleprompterFontSize = defaults.double(forKey: "teleprompterFontSize")
        launchAtLogin = false
        let stored = UserDefaults.standard
        features = Set(Feature.available.filter { stored.bool(forKey: Self.featureKey($0)) })
        readLaunchAtLogin()
    }

    // MARK: Features

    func isEnabled(_ feature: Feature) -> Bool {
        features.contains(feature)
    }

    func setEnabled(_ feature: Feature, _ enabled: Bool) {
        guard Feature.available.contains(feature), enabled != isEnabled(feature) else { return }
        if enabled { features.insert(feature) } else { features.remove(feature) }
        defaults.set(enabled, forKey: Self.featureKey(feature))
    }

    /// Whether `feature` is on, now and whenever it changes.
    func publisher(for feature: Feature) -> AnyPublisher<Bool, Never> {
        $features.map { $0.contains(feature) }.removeDuplicates().eraseToAnyPublisher()
    }

    private static func featureKey(_ feature: Feature) -> String { "feature.\(feature.rawValue)" }

    /// Whether an activity of this kind should be shown at all.
    func allows(_ kind: ActivityKind) -> Bool {
        switch kind {
        case .charging, .lowBattery: return showChargingActivity
        case .audioDevice: return showDeviceActivity
        case .volume: return showVolumeActivity
        case .brightness: return showBrightnessActivity
        case .taskDue: return showTaskReminders
        case .meetingReminder: return showMeetingReminders
        case .copied: return showCopyActivity
        case .keepAwake: return true
        case .agentApproval, .agentFinished: return isEnabled(.agents)
        case .notification(let notification):
            return isEnabled(.notifications) && notificationApps.contains(notification.bundleID.lowercased())
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        // Re-read rather than trusting `enabled`: the user may need to approve it in System Settings.
        readLaunchAtLogin()
    }

    /// Call when the settings window opens, in case the login item was changed in System Settings.
    func reloadLaunchAtLogin() {
        readLaunchAtLogin()
        refreshAccessibility()
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private func readLaunchAtLogin() {
        let status = SMAppService.mainApp.status
        launchAtLogin = status == .enabled
        launchAtLoginNeedsApproval = status == .requiresApproval
    }

    /// Re-reads whether Topsail may filter keyboard events and returns it.
    ///
    /// This is the event-access check, not `AXIsProcessTrusted()`: the AX API (controlling other
    /// apps) is unavailable to sandboxed apps and always reports false, while event access is
    /// the permission an active event tap needs and works under the App Sandbox.
    @discardableResult
    func refreshAccessibility() -> Bool {
        // Once the tap exists, access is proven; the preflight answer is fixed for the life of
        // the process and would keep reporting the state at launch.
        // A filtering key tap needs both Input Monitoring (macOS checks it first when the tap is
        // created) and event posting; both are listed under Privacy & Security.
        let granted = accessibilityGranted || (CGPreflightListenEventAccess() && CGPreflightPostEventAccess())
        if granted != accessibilityGranted {
            accessibilityGranted = granted
        }
        return granted
    }

    /// Called when an event tap was created: access is granted even if the preflight check,
    /// answered once at launch, still says otherwise.
    func noteEventAccessGranted() {
        if !accessibilityGranted {
            accessibilityGranted = true
        }
    }

    /// Shows the system prompts that add Topsail to Input Monitoring and Accessibility.
    func requestAccessibility() {
        // Each call shows its own system prompt the first time; Input Monitoring is the one the
        // tap is refused without.
        CGRequestListenEventAccess()
        CGRequestPostEventAccess()
    }

    /// Opens the Privacy & Security list Topsail is still missing from: Input Monitoring first (the
    /// key tap is refused without it), then Accessibility.
    func openKeyAccessSettings() {
        let pane = CGPreflightListenEventAccess() ? "Privacy_Accessibility" : "Privacy_ListenEvent"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// The App Store build leaves the volume keys to macOS until the user asks Topsail to handle
    /// them (and so is asked for Input Monitoring and Accessibility only then); the direct build
    /// takes them from the start.
    #if DIRECT
    private static let takesOverKeysByDefault = true
    #else
    private static let takesOverKeysByDefault = false
    #endif

    private func save(_ value: Bool, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
