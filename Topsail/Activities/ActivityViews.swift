import SwiftUI

/// A transient activity beside the notch: an icon in the left wing, a value in the right wing.
/// A charger connecting gets its own moment, `ChargingSweep`; low battery, a call starting and a
/// device connecting get cards below the camera (`LowBatteryNotice`, `MeetingReminderNotice`,
/// `DeviceConnectedNotice`). Toasts (a copy, Keep Awake, volume and brightness) are not shown
/// here at all: they have the band at the island's base (`ToastBand`).
struct TransientActivityView: View {
    let activity: TransientActivity
    let notchSize: CGSize
    let wingWidth: CGFloat
    /// Height of the stage below the notch, for the charging moment.
    let meterHeight: CGFloat
    /// The low-battery notice was clicked.
    var onRequestLowPowerMode: () -> Void = {}
    /// One of the meeting reminder's buttons was clicked.
    var onMeetingAnswer: (UpcomingEvent, MeetingAnswer) -> Void = { _, _ in }
    /// Whether notifications show their text, or only who they're from.
    var showsNotificationText = true
    /// Deny or Approve on an agent's request.
    var onAgentAnswer: (AgentApproval, Bool?) -> Void = { _, _ in }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch activity.kind {
        case .charging(let level):
            ChargingSweep(level: level, notchSize: notchSize, wingWidth: wingWidth, stageHeight: meterHeight)
                .traced("wings.charging")
        case .lowBattery(let level, let lowPowerMode):
            LowBatteryNotice(level: level, lowPowerMode: lowPowerMode, notchSize: notchSize,
                             onClick: onRequestLowPowerMode)
                .traced("notice.lowBattery")
        case .meetingReminder(let meeting):
            MeetingReminderNotice(meeting: meeting, notchSize: notchSize) { onMeetingAnswer(meeting, $0) }
                .traced("notice.meetingReminder")
        case .audioDevice(let name, let battery):
            DeviceConnectedNotice(name: name, battery: battery, notchSize: notchSize)
                .traced("notice.audioDevice")
        case .agentApproval(let approval):
            AgentApprovalNotice(approval: approval, notchSize: notchSize) { onAgentAnswer(approval, $0) }
                .traced("notice.agentApproval")
        case .notification(let notification):
            NotificationNotice(notification: notification, showsText: showsNotificationText, notchSize: notchSize)
                .traced("notice.notification")
        case .recorder(let notice):
            RecorderNoticeView(notice: notice, notchSize: notchSize)
                .traced("notice.recorder")
        default:
            wings
                .traced("wings.\(activity.kind.traceName)")
        }
    }

    private var wings: some View {
        HStack(spacing: 0) {
            leftWing
                .padding(.leading, 12)
                .frame(width: wingWidth, height: notchSize.height, alignment: .leading)

            Color.clear
                .frame(width: notchSize.width, height: notchSize.height)

            rightWing
                .padding(.trailing, 12)
                .frame(width: wingWidth, height: notchSize.height, alignment: .trailing)
        }
    }

    // MARK: Wings

    @ViewBuilder
    private var leftWing: some View {
        switch activity.kind {
        case .charging, .lowBattery, .meetingReminder, .audioDevice:
            EmptyView()  // ChargingSweep and the notices draw their own.
        case .agentApproval, .notification, .recorder:
            EmptyView()
        case .copied, .keepAwake, .volume, .brightness:
            EmptyView()  // Toasts: the band at the island's base.
        case .agentFinished(let agent, _):
            HStack(spacing: 5) {
                icon(agent.symbol, agent.color)
                Text(agent.shortName)
                    .font(Self.valueFont)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        case .taskDue(let title, let overdue):
            HStack(spacing: 5) {
                icon("checklist", overdue ? .red : .orange)
                Text(title)
                    .font(Self.valueFont)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    @ViewBuilder
    private var rightWing: some View {
        switch activity.kind {
        case .charging, .lowBattery, .meetingReminder, .audioDevice:
            EmptyView()
        case .taskDue(_, let overdue):
            value(overdue ? String(localized: "Overdue") : String(localized: "Due today"), overdue ? .red : .orange)
        case .agentApproval, .notification, .recorder:
            EmptyView()
        case .copied, .keepAwake, .volume, .brightness:
            EmptyView()
        case .agentFinished(_, let project):
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.green)
                Text(project.isEmpty ? String(localized: "Done") : project)
                    .font(Self.valueFont)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private static let valueFont = Font.system(size: 12, weight: .semibold).monospacedDigit()
    /// Keep Awake's warm amber.
    static let awake = Color(red: 1, green: 0.74, blue: 0.3)

    private func icon(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(color)
    }

    private func value(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(Self.valueFont)
            .foregroundStyle(color)
    }

}

/// What a level is of: this Mac's volume, a Spotify device's, or the display's brightness.
struct LevelGlyph: View {
    let kind: ActivityKind
    var size: CGFloat = 13
    var tint: Color = .white

    var body: some View {
        Group {
            switch kind {
            case .volume(let level, let muted, let remote) where remote:
                // Spotify playing on another device: that device, not this Mac's speaker.
                Image(systemName: "hifispeaker.fill")
                    .foregroundStyle(tint.opacity(muted || level == 0 ? 0.5 : 1))
            case .volume(let level, let muted, _):
                Image(systemName: muted || level == 0 ? "speaker.slash.fill" : "speaker.wave.3.fill",
                      variableValue: Double(level))
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
            case .brightness(let level):
                Image(systemName: level < 0.5 ? "sun.min.fill" : "sun.max.fill")
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
            default:
                EmptyView()
            }
        }
        .font(.system(size: size, weight: .semibold))
        .accessibilityHidden(true)
    }
}

/// A 3 pt line filled to `level` with a soft glow: the level in a volume or brightness toast.
/// It follows the keys, so it springs (`Motion.snappy`).
struct LevelMeter: View {
    let level: Double
    let color: Color
    let dimmed: Bool
    /// Clear of the island's rounded corners.
    var inset: CGFloat = 14

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let thickness: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.18))
                Capsule()
                    .fill(color.opacity(dimmed ? 0.35 : 1))
                    .frame(width: max(thickness, width * min(max(level, 0), 1)))
                    .shadow(color: color.opacity(dimmed ? 0 : 0.55), radius: 3)
            }
            .frame(height: thickness)
            .animation(reduceMotion ? nil : Motion.snappy, value: level)
            .animation(reduceMotion ? nil : Motion.fadeFast, value: dimmed)
        }
        .frame(height: thickness)
        .padding(.horizontal, inset)
        .padding(.top, inset > 0 ? 1 : 0)
    }
}
