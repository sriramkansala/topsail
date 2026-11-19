import SwiftUI

/// A call is starting: the island drops a card below the camera, like the low-battery notice,
/// with the call's title and when it starts, then "Remind me in 5 min" on the left and Ignore and
/// Join on the right. It stays until one of them is clicked, or until the call can no longer be
/// joined.
struct MeetingReminderNotice: View {
    let meeting: UpcomingEvent
    let notchSize: CGSize
    let onAnswer: (MeetingAnswer) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: notchSize.height)

            VStack(alignment: .leading, spacing: IslandLayout.reminderRowGap) {
                header
                HStack(spacing: 8) {
                    ReminderButton(title: "Remind me in 5 min", symbol: "clock") { onAnswer(.snooze) }
                        .accessibilityHint("Shows this reminder again in five minutes")
                    Spacer(minLength: 8)
                    ReminderButton(title: "Ignore") { onAnswer(.ignore) }
                        .accessibilityHint("No more reminders for this call")
                    ReminderButton(title: "Join", symbol: "video.fill", tint: .green) { onAnswer(.join) }
                        .accessibilityHint("Opens the meeting link")
                }
            }
            .padding(.horizontal, IslandLayout.reminderInset)
            .padding(.top, IslandLayout.noticeTopGap)
            .padding(.bottom, IslandLayout.reminderInset)
        }
        .accessibilityElement(children: .contain)
    }

    /// The call's colour and camera, its title, and when it starts and where.
    private var header: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(meeting.color.opacity(0.22))
                .overlay {
                    Image(systemName: "video.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(meeting.color)
                }
                .frame(width: IslandLayout.reminderHeaderHeight, height: IslandLayout.reminderHeaderHeight)

            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title.isEmpty ? "Meeting" : meeting.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                // When it starts changes once a minute; the text is always the current value.
                TimelineView(.everyMinute) { context in
                    Text(subtitle(at: context.date))
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .tracking(-0.2)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: IslandLayout.reminderHeaderHeight)
        .accessibilityElement(children: .combine)
    }

    private func subtitle(at now: Date) -> String {
        let when = Self.when(meeting.start, from: now)
        guard let url = meeting.joinURL, let service = MeetingLink.service(of: url) else { return when }
        return "\(when) · \(service)"
    }

    static func when(_ start: Date, from now: Date) -> String {
        let until = start.timeIntervalSince(now)
        if until > 0 {
            return "Starts in \(Int((until / 60).rounded(.up))) min"
        }
        let ago = Int((-until / 60).rounded(.down))
        return ago < 1 ? "Starting now" : "Started \(ago) min ago"
    }
}

/// One of the reminder's buttons: a quiet capsule, or a filled one for Join. Brightens under the
/// pointer, sinks when pressed.
private struct ReminderButton: View {
    let title: String
    var symbol: String?
    /// The fill of the one button that matters (Join); nil for a quiet one.
    var tint: Color?
    let action: () -> Void

    @State private var hovering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 10.5, weight: .semibold))
                }
                Text(title)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(tint == nil ? Color.white.opacity(0.85) : .white)
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 12)
            .frame(height: IslandLayout.reminderButtonHeight)
            .background(Capsule().fill(fill))
            .contentShape(Capsule())
        }
        .buttonStyle(.pressable(.normal, hoverWash: false))
        .onHover { hovering = $0 }
        .animation(reduceMotion ? nil : Motion.hover, value: hovering)
    }

    private var fill: Color {
        if let tint { return tint.opacity(hovering ? 1 : 0.85) }
        return .white.opacity(hovering ? 0.18 : 0.11)
    }
}
