import SwiftUI

/// A transient activity beside the notch: an icon in the left wing, a value in the right wing,
/// and — for volume and brightness — a level meter along the island's bottom edge, so the island
/// itself becomes the gauge. A charger connecting gets its own moment, `ChargingSweep`; low
/// battery, a call starting and a device connecting get cards below the camera
/// (`LowBatteryNotice`, `MeetingReminderNotice`, `DeviceConnectedNotice`).
struct TransientActivityView: View {
    let activity: TransientActivity
    let notchSize: CGSize
    let wingWidth: CGFloat
    /// Height of the strip below the notch that holds the meter (0 = no meter).
    let meterHeight: CGFloat
    /// The low-battery notice was clicked.
    var onRequestLowPowerMode: () -> Void = {}
    /// One of the meeting reminder's buttons was clicked.
    var onMeetingAnswer: (UpcomingEvent, MeetingAnswer) -> Void = { _, _ in }
    /// Whether notifications show their text, or only who they're from.
    var showsNotificationText = true
    /// Deny or Approve on an agent's request.
    var onAgentAnswer: (AgentApproval, Bool?) -> Void = { _, _ in }
    /// What is playing, which a device connecting or a copy keeps beside the notch; nil when
    /// nothing is.
    var nowPlaying: NowPlayingService? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        switch activity.kind {
        case .charging(let level):
            ChargingSweep(level: level, notchSize: notchSize, wingWidth: wingWidth, stageHeight: meterHeight)
        case .lowBattery(let level, let lowPowerMode):
            LowBatteryNotice(level: level, lowPowerMode: lowPowerMode, notchSize: notchSize,
                             onClick: onRequestLowPowerMode)
        case .meetingReminder(let meeting):
            MeetingReminderNotice(meeting: meeting, notchSize: notchSize) { onMeetingAnswer(meeting, $0) }
        case .audioDevice(let name, let battery):
            DeviceConnectedNotice(name: name, battery: battery, notchSize: notchSize, wingWidth: wingWidth,
                                  nowPlaying: nowPlaying)
        case .copied:
            CopiedNotice(notchSize: notchSize, wingWidth: wingWidth, nowPlaying: nowPlaying)
        case .agentApproval(let approval):
            AgentApprovalNotice(approval: approval, notchSize: notchSize) { onAgentAnswer(approval, $0) }
        case .notification(let notification):
            NotificationNotice(notification: notification, showsText: showsNotificationText, notchSize: notchSize)
        case .recorder(let notice):
            RecorderNoticeView(notice: notice, notchSize: notchSize)
        default:
            wingsAndMeter
        }
    }

    private var wingsAndMeter: some View {
        VStack(spacing: 0) {
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

            if meterHeight > 0, let meter {
                LevelMeter(level: meter.level, color: meter.color, dimmed: meter.dimmed)
                    .frame(height: meterHeight, alignment: .top)
            }
        }
    }

    // MARK: Wings

    @ViewBuilder
    private var leftWing: some View {
        switch activity.kind {
        case .volume, .brightness:
            LevelGlyph(kind: activity.kind)
        case .charging, .lowBattery, .meetingReminder, .audioDevice, .copied:
            EmptyView()  // ChargingSweep and the notices draw their own.
        case .agentApproval, .notification, .recorder:
            EmptyView()
        case .agentFinished(let agent, _):
            HStack(spacing: 5) {
                icon(agent.symbol, agent.color)
                Text(agent.shortName)
                    .font(Self.valueFont)
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        case .keepAwake(let on):
            HStack(spacing: 5) {
                icon(on ? "cup.and.saucer.fill" : "cup.and.saucer", on ? Self.awake : .white.opacity(0.5))
                Text("Keep Awake")
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
        case .volume(let level, let muted, _):
            // The number is a derived value: the text is always the final value; only its
            // digits roll, on base, so correctness never depends on the animation.
            Text("\(Int(((muted ? 0 : level) * 100).rounded()))")
                .font(Self.valueFont)
                .foregroundStyle(.white.opacity(muted ? 0.5 : 1))
                .contentTransition(.numericText(value: Double(level)))
                .animation(reduceMotion ? nil : Motion.base, value: level)
        case .brightness(let level):
            Text("\(Int((level * 100).rounded()))")
                .font(Self.valueFont)
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: Double(level)))
                .animation(reduceMotion ? nil : Motion.base, value: level)
        case .charging, .lowBattery, .meetingReminder, .audioDevice, .copied:
            EmptyView()
        case .taskDue(_, let overdue):
            value(overdue ? String(localized: "Overdue") : String(localized: "Due today"), overdue ? .red : .orange)
        case .keepAwake(let on):
            value(on ? String(localized: "On") : String(localized: "Off"), on ? Self.awake : .white.opacity(0.5))
        case .agentApproval, .notification, .recorder:
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

    // MARK: Meter

    private var meter: (level: Double, color: Color, dimmed: Bool)? {
        activity.kind.levelReading.map { ($0.value, .white, $0.dimmed) }
    }
}

/// What a level is of: this Mac's volume, a Spotify device's, or the display's brightness.
struct LevelGlyph: View {
    let kind: ActivityKind
    var size: CGFloat = 13

    var body: some View {
        Group {
            switch kind {
            case .volume(let level, let muted, let remote) where remote:
                // Spotify playing on another device: that device, not this Mac's speaker.
                Image(systemName: "hifispeaker.fill")
                    .foregroundStyle(.white.opacity(muted || level == 0 ? 0.5 : 1))
            case .volume(let level, let muted, _):
                Image(systemName: muted || level == 0 ? "speaker.slash.fill" : "speaker.wave.3.fill",
                      variableValue: Double(level))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            case .brightness(let level):
                Image(systemName: level < 0.5 ? "sun.min.fill" : "sun.max.fill")
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            default:
                EmptyView()
            }
        }
        .font(.system(size: size, weight: .semibold))
        .accessibilityHidden(true)
    }
}

/// A level in the open island's own bottom margin, on pages that don't show it themselves.
struct ExpandedLevelIndicator: View {
    let kind: ActivityKind

    var body: some View {
        if let reading = kind.levelReading {
            HStack(spacing: 8) {
                LevelGlyph(kind: kind, size: 9)
                LevelMeter(level: reading.value, color: .white, dimmed: reading.dimmed, inset: 0)
                    .frame(width: 120)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: "\(kind.levelPercent ?? 0)%"))
        }
    }
}

/// A 3 pt line along the island's bottom edge, inset clear of the rounded corners, filled to
/// `level` with a soft glow. It follows the keys, so it springs (`Motion.snappy`).
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
            .animation(reduceMotion ? nil : Motion.fast, value: dimmed)
        }
        .frame(height: thickness)
        .padding(.horizontal, inset)
        .padding(.top, inset > 0 ? 1 : 0)
    }
}
