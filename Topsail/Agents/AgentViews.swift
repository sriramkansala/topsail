import SwiftUI

/// An agent asks before a command: a card below the camera with who asks and in which project,
/// the command itself, how long it waits, and Deny / Approve. Unanswered, it leaves when the
/// time is up and the agent asks in its own window instead.
struct AgentApprovalNotice: View {
    let approval: AgentApproval
    let notchSize: CGSize
    /// true: approve, false: deny, nil: let the agent ask in its own window.
    let onAnswer: (Bool?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchSize.height)

            VStack(alignment: .leading, spacing: IslandLayout.approvalGap) {
                HStack(spacing: 10) {
                    AgentGlyph(agent: approval.agent, size: IslandLayout.approvalHeaderHeight)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(approval.title)
                            .font(.system(size: 13.5, weight: .medium))
                            .foregroundColor(.white)
                        if !approval.project.isEmpty {
                            Text(approval.project)
                                .font(.system(size: 11.5))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .lineLimit(1)
                }
                .frame(height: IslandLayout.approvalHeaderHeight)

                Text(approval.isReviewable ? approval.shownDetail
                                           : String(localized: "Too long to show here in full. Review it in \(approval.agent.name)."))
                    .font(.system(size: 11.5, design: approval.isReviewable ? .monospaced : .default))
                    .foregroundColor(.white.opacity(approval.isReviewable ? 0.9 : 0.55))
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, minHeight: IslandLayout.approvalDetailHeight, alignment: .topLeading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.07)))
                    .frame(height: IslandLayout.approvalDetailHeight + 12)

                HStack(spacing: 8) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let left = max(0, Int(approval.expires.timeIntervalSince(context.date).rounded()))
                        Text("\(left) s")
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer(minLength: 8)
                    ReminderButton(title: String(localized: "Deny")) { onAnswer(false) }
                        .accessibilityHint("Stops the command")
                    AnswerButton(approval: approval, onAnswer: onAnswer)
                }
            }
            .padding(.horizontal, IslandLayout.reminderInset)
            .padding(.top, IslandLayout.noticeTopGap)
            .padding(.bottom, IslandLayout.reminderInset)
        }
        .accessibilityElement(children: .contain)
    }
}

/// Approve, or, for something the notch can't show whole, a way to the agent's own prompt.
private struct AnswerButton: View {
    let approval: AgentApproval
    let onAnswer: (Bool?) -> Void

    var body: some View {
        if approval.isReviewable {
            ReminderButton(title: String(localized: "Approve"), symbol: "checkmark", tint: .green) { onAnswer(true) }
                .accessibilityHint("Lets it go ahead")
        } else {
            ReminderButton(title: String(localized: "Review there")) { onAnswer(nil) }
                .accessibilityHint("Lets the agent ask in its own window")
        }
    }
}

/// An agent's glyph on a tile of its colour.
struct AgentGlyph: View {
    let agent: AgentKind
    var size: CGFloat = 24

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(agent.color.opacity(0.22))
            .overlay {
                Image(systemName: agent.symbol)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundColor(agent.color)
            }
            .frame(width: size, height: size)
    }
}

/// An agent working, beside the notch while nothing else is: its glyph, and dots that ripple.
struct AgentWorkingWings: View {
    let agent: AgentKind
    let notchSize: CGSize
    let wingWidth: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: agent.symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(agent.color)
                .symbolEffect(.pulse, options: .repeating)
                .frame(width: wingWidth, height: notchSize.height)

            Color.clear
                .frame(width: notchSize.width, height: notchSize.height)

            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .symbolEffect(.variableColor.iterative, options: .repeating)
                .frame(width: wingWidth, height: notchSize.height)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(agent.name) is working")
    }
}

/// The Agents page: requests waiting for an answer first, then each session, what it's doing
/// and for how long.
struct AgentsPageView: View {
    @ObservedObject var hub: AgentHub
    let connected: Bool

    var body: some View {
        if hub.approvals.isEmpty && hub.sessions.isEmpty {
            MessageView(symbol: "sparkles", text: connected ? String(localized: "No agents running")
                                                             : String(localized: "Connect your agents in Settings › Integrations"))
        } else {
            let rows = VStack(spacing: IslandLayout.agentRowSpacing) {
                ForEach(hub.approvals) { approval in
                    ApprovalRow(approval: approval) { hub.answer(approval, approve: $0) }
                }
                ForEach(Self.ordered(hub.sessions)) { session in
                    SessionRow(session: session) { hub.dismiss(session) }
                }
            }
            if IslandLayout.agentsNaturalHeight(approvals: hub.approvals.count, sessions: hub.sessions.count)
                > IslandLayout.agentsMaxHeight {
                ScrollView(.vertical, showsIndicators: false) { rows }
            } else {
                rows
            }
        }
    }

    /// Working first, then waiting, then finished; most recent first within each.
    static func ordered(_ sessions: [AgentSession]) -> [AgentSession] {
        func rank(_ s: AgentSession) -> Int {
            switch s.status {
            case .waiting: return 0
            case .working: return 1
            case .finished: return 2
            }
        }
        return sessions.sorted { rank($0) != rank($1) ? rank($0) < rank($1) : $0.since > $1.since }
    }
}

private struct SessionRow: View {
    let session: AgentSession
    let dismiss: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            AgentGlyph(agent: session.agent)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(session.project.isEmpty ? session.agent.name : session.project)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.white)
                    if !session.project.isEmpty {
                        Text(session.agent.name)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                }
                Text(statusText)
                    .font(.system(size: 11, design: isCommand ? .monospaced : .default))
                    .foregroundColor(statusColor)
            }
            .lineLimit(1)
            .truncationMode(.tail)
            Spacer(minLength: 8)
            if session.status == .finished && hovering {
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.pressable)
                .help("Clear")
            } else {
                TimelineView(.everyMinute) { context in
                    Text(Self.age(from: session.since, to: context.date))
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }
        .frame(height: IslandLayout.agentRowHeight)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    private var statusText: String {
        switch session.status {
        case .working(let activity): return activity ?? String(localized: "Working")
        case .waiting(let message): return message ?? String(localized: "Waiting for you")
        case .finished: return String(localized: "Finished")
        }
    }

    private var isCommand: Bool {
        if case .working(let activity?) = session.status { return activity.hasPrefix(String(localized: "Running ")) }
        return false
    }

    private var statusColor: Color {
        switch session.status {
        case .working: return .white.opacity(0.6)
        case .waiting: return Color(red: 1, green: 0.74, blue: 0.3)
        case .finished: return .green.opacity(0.85)
        }
    }

    static func age(from date: Date, to now: Date) -> String {
        let minutes = Int(now.timeIntervalSince(date) / 60)
        if minutes < 1 { return String(localized: "now") }
        if minutes < 60 { return "\(minutes)m" }
        return "\(minutes / 60)h"
    }
}

/// A request on the Agents page: who, the command, Deny / Approve.
private struct ApprovalRow: View {
    let approval: AgentApproval
    let answer: (Bool?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                AgentGlyph(agent: approval.agent)
                Text(approval.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                ReminderButton(title: String(localized: "Deny")) { answer(false) }
                AnswerButton(approval: approval, onAnswer: answer)
            }
            Text(approval.isReviewable ? approval.shownDetail
                                       : String(localized: "Too long to show here in full. Review it in \(approval.agent.name)."))
                .font(.system(size: 11, design: approval.isReviewable ? .monospaced : .default))
                .foregroundColor(.white.opacity(0.75))
                .lineLimit(3)
                .minimumScaleFactor(0.85)
                .padding(.leading, 34)
        }
        .frame(height: IslandLayout.approvalRowHeight)
    }
}
