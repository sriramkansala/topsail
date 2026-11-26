import Foundation

/// Features that ship switched off and are turned on, one by one, in Settings › Features. Some
/// need what only the direct download can have (another app's settings files, Full Disk Access,
/// scripting other apps, replacing itself), so the App Store build doesn't list them.
enum Feature: String, CaseIterable, Identifiable {
    case shelf
    case reminders
    case keepAwake
    case teleprompter
    case recorder
    case agents
    case notifications
    case apps
    case autoUpdates

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shelf: return String(localized: "File shelf")
        case .reminders: return String(localized: "Reminders")
        case .keepAwake: return String(localized: "Keep Awake")
        case .teleprompter: return String(localized: "Teleprompter")
        case .recorder: return String(localized: "Screen and call recorder")
        case .agents: return String(localized: "AI coding agents")
        case .notifications: return String(localized: "Notifications")
        case .apps: return String(localized: "Terminal, Chrome and YouTube")
        case .autoUpdates: return String(localized: "Automatic updates")
        }
    }

    var summary: String {
        switch self {
        case .shelf:
            return String(localized: "Drag files onto the notch to keep them at hand across apps; drag them back out, or AirDrop them from there.")
        case .reminders:
            return String(localized: "Your Apple Reminders next to your calendar: tick them off or add one from the island.")
        case .keepAwake:
            return String(localized: "A button in the island that stops your Mac sleeping during a long job.")
        case .teleprompter:
            return String(localized: "Your script scrolls out of the notch, right under the camera, at your pace.")
        case .recorder:
            return String(localized: "Record your screen, or a call's audio, and start, pause and stop it from the notch.")
        case .agents:
            return String(localized: "Claude Code, Codex, Cursor and Antigravity show their progress in the notch and ask you there before risky commands.")
        case .notifications:
            return String(localized: "Messages, Slack, Mail and other apps' alerts slide out of the notch.")
        case .apps:
            return String(localized: "An Apps tab with your Terminal's output, Chrome's tabs and a YouTube play button, while those apps are open.")
        case .autoUpdates:
            return String(localized: "Topsail checks for new versions every day and installs them when it next restarts.")
        }
    }

    var symbol: String {
        switch self {
        case .shelf: return "tray.full"
        case .reminders: return "checklist"
        case .keepAwake: return "cup.and.saucer.fill"
        case .teleprompter: return "text.alignleft"
        case .recorder: return "record.circle"
        case .agents: return "sparkles"
        case .notifications: return "bell.badge"
        case .apps: return "square.grid.2x2"
        case .autoUpdates: return "arrow.down.circle"
        }
    }

    /// Needs the direct download: the App Store build can't do it.
    var directOnly: Bool {
        switch self {
        case .agents, .notifications, .apps, .autoUpdates: return true
        case .shelf, .reminders, .keepAwake, .teleprompter, .recorder: return false
        }
    }

    /// The features this build can offer, in Settings order.
    static var available: [Feature] {
        #if DIRECT
        return allCases
        #else
        return allCases.filter { !$0.directOnly }
        #endif
    }
}
