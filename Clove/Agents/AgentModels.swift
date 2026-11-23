import SwiftUI

/// The AI coding agents Clove follows (direct download only; see `AgentHub`).
enum AgentKind: String, CaseIterable, Identifiable {
    case claude
    case codex
    case cursor
    case antigravity

    var id: String { rawValue }

    var name: String {
        switch self {
        case .claude: return "Claude Code"
        case .codex: return "Codex"
        case .cursor: return "Cursor"
        case .antigravity: return "Antigravity"
        }
    }

    /// Short, for beside the notch.
    var shortName: String {
        switch self {
        case .claude: return "Claude"
        default: return name
        }
    }

    /// A plain glyph and colour per agent (no logos).
    var symbol: String {
        switch self {
        case .claude: return "asterisk"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .cursor: return "cursorarrow.rays"
        case .antigravity: return "arrow.up.forward.circle"
        }
    }

    var color: Color {
        switch self {
        case .claude: return Color(red: 0.85, green: 0.47, blue: 0.34)
        case .codex: return Color(red: 0.45, green: 0.78, blue: 0.62)
        case .cursor: return Color(white: 0.85)
        case .antigravity: return Color(red: 0.42, green: 0.62, blue: 1)
        }
    }
}

/// One agent session: which agent, in which project, doing what.
struct AgentSession: Identifiable, Equatable {
    enum Status: Equatable {
        /// Working; what it's doing right now, if known ("Running npm test").
        case working(String?)
        /// Waiting for the user: a question, an approval, or its next prompt.
        case waiting(String?)
        case finished
    }

    let id: String
    let agent: AgentKind
    var project: String
    var status: Status
    /// When the current status began.
    var since: Date
    let startedAt: Date

    var isWorking: Bool {
        if case .working = status { return true }
        return false
    }
}

/// An agent asking before a command or edit: answered with Approve or Deny in the notch, or left
/// to the agent's own prompt if not answered by `expires`.
struct AgentApproval: Identifiable, Equatable {
    let id: UUID
    let agent: AgentKind
    let project: String
    /// "run", "edit", "use"…, as in "Claude Code wants to run".
    let verb: String
    /// The command, the file, or the tool.
    let detail: String
    let expires: Date

    var title: String {
        String(localized: "\(agent.name) wants to \(verb)")
    }

    /// `detail` with invisible and direction-changing characters spelled out, so a command can't
    /// look like a different one.
    var shownDetail: String {
        var shown = ""
        for scalar in detail.unicodeScalars {
            switch scalar.properties.generalCategory {
            case .control where scalar == "\n":
                shown.unicodeScalars.append(scalar)
            case .control, .format, .lineSeparator, .paragraphSeparator, .privateUse, .surrogate, .unassigned:
                shown += "\\u{" + String(scalar.value, radix: 16) + "}"
            default:
                shown.unicodeScalars.append(scalar)
            }
        }
        return shown
    }

    /// Whether the card shows all of it. Approving something partly hidden isn't offered: the
    /// agent's own window, which shows everything, asks instead.
    var isReviewable: Bool {
        let lines = shownDetail.split(separator: "\n", omittingEmptySubsequences: false)
            .reduce(0) { $0 + max(1, Int((Double($1.count) / 40).rounded(.up))) }
        return lines <= 3
    }
}
