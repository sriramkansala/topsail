import Foundation
import SwiftUI

enum ActivityKind: Equatable {
    case charging(level: Int)          // just plugged in
    case lowBattery(level: Int, lowPowerMode: LowPowerMode)  // crossed 20 % or 10 % while on battery
    case audioDevice(name: String, battery: DeviceBattery?)  // default output switched to a Bluetooth device
    case volume(level: Float, muted: Bool, remote: Bool = false)  // output volume changed; level is 0...1; remote: Spotify's device elsewhere
    case brightness(level: Float)           // display brightness changed (direct build only)
    case taskDue(title: String, overdue: Bool)  // a Linear issue is due today or overdue
    case meetingReminder(UpcomingEvent)    // a call is starting: Join, Ignore or Remind me in 5 min
    case copied(snippet: String? = nil)    // something was copied: a toast, with a glimpse of it when known
    case keepAwake(on: Bool)               // Keep Awake was turned on or off: a toast
    case agentApproval(AgentApproval)      // an AI agent asks before a command: Deny or Approve
    case agentFinished(agent: AgentKind, project: String)  // an AI agent finished its turn
    case notification(MirroredNotification)  // another app's notification
    case recorder(RecorderNotice)          // a recording saved or failed, an offer to record a call
}

/// The meeting reminder's three buttons.
enum MeetingAnswer {
    case join, ignore, snooze
}

/// Where Low Power Mode stands for the low-battery notice.
enum LowPowerMode: Equatable {
    /// Off: the notice offers it.
    case off
    /// The notice was clicked and the direct build's helper needs allowing in Login Items first
    /// (once); the notice waits for it.
    case approving
    /// The notice was clicked and Battery settings are opening; the notice waits for it there.
    case requested
    /// On: the notice is gold.
    case on
}

extension ActivityKind {
    /// The low-battery notice, the meeting reminder and a device connecting: cards below the
    /// camera that the pointer can rest on (they stay put instead of opening the island).
    var isNotice: Bool {
        switch self {
        case .lowBattery, .meetingReminder, .audioDevice, .agentApproval, .notification, .recorder: return true
        default: return false
        }
    }

    var isClickable: Bool {
        switch self {
        case .lowBattery(_, .off), .meetingReminder, .agentApproval, .notification, .recorder: return true
        default: return false
        }
    }

    /// The meeting reminder stays until one of its buttons is clicked (or the call can no longer
    /// be joined), wherever the pointer goes.
    var waitsForAnswer: Bool {
        switch self {
        case .meetingReminder, .agentApproval: return true
        default: return false
        }
    }

    /// A toast: the user's own action, confirmed in the band at the base of the island, closed
    /// or open. A copy, Keep Awake switched, a level being adjusted (volume, brightness). Shown
    /// at once and updated in place; it never takes the island over, changes the page or covers
    /// anything.
    var isToast: Bool {
        switch self {
        case .volume, .brightness, .copied, .keepAwake: return true
        case .charging, .lowBattery, .audioDevice, .taskDue, .meetingReminder, .agentApproval, .agentFinished,
             .notification, .recorder: return false
        }
    }

    /// A device connecting keeps the music's artwork and bars in the notch row above its card.
    var keepsMusicBesideNotch: Bool {
        if case .audioDevice = self { return true }
        return false
    }

    /// A level's reading, 0...1, and whether it's muted (shown dimmed).
    var levelReading: (value: Double, dimmed: Bool)? {
        switch self {
        case .volume(let level, let muted, _): return (Double(level), muted)
        case .brightness(let level): return (Double(level), false)
        default: return nil
        }
    }

    /// A level as the percentage shown: a muted volume reads 0.
    var levelPercent: Int? {
        switch self {
        case .volume(let level, let muted, _): return Int(((muted ? 0 : level) * 100).rounded())
        case .brightness(let level): return Int((level * 100).rounded())
        default: return nil
        }
    }

    /// The same toast with a newer value: it updates in place instead of leaving and arriving.
    func isSameToast(as other: ActivityKind) -> Bool {
        switch (self, other) {
        case (.volume, .volume), (.brightness, .brightness), (.copied, .copied), (.keepAwake, .keepAwake): return true
        default: return false
        }
    }
}

struct TransientActivity: Identifiable, Equatable {
    var id = UUID()
    let kind: ActivityKind
}

/// Queues short "live activities" that are shown beside the notch for a few seconds,
/// one at a time, while the island is collapsed; and shows toasts, which have their own place
/// (the band at the island's base) and so never wait for, or interrupt, an activity.
@MainActor
final class ActivityCenter: ObservableObject {
    @Published private(set) var current: TransientActivity?
    /// The toast in the band at the base of the island, closed or open.
    @Published private(set) var toast: TransientActivity?
    /// Settings filter; activities it rejects are dropped.
    var isAllowed: (ActivityKind) -> Bool = { _ in true }

    private var queue: [ActivityKind] = []
    private var pendingWork: DispatchWorkItem?
    private var toastWork: DispatchWorkItem?
    private let displayDuration: TimeInterval = 3
    /// A toast stays this long after its last update (a held key keeps it up).
    private let toastDuration: TimeInterval = 1.5
    /// "Copied": a little longer, to read what was copied.
    private let copiedDuration: TimeInterval = 2.5
    /// A device connecting: long enough to read each battery.
    private let deviceDuration: TimeInterval = 4
    /// The low-battery notice gives the user time to reach it, and to finish in System Settings.
    private let noticeDuration: TimeInterval = 6
    private let lowPowerWait: TimeInterval = 30
    /// How long a notice stays once the pointer leaves it.
    private let noticeLinger: TimeInterval = 2
    private let maxQueued = 3
    private var pointerInside = false

    /// Width of each wing beside the notch for the activity being shown.
    var wingWidth: CGFloat {
        current == nil ? 0 : IslandLayout.activityWing
    }

    /// Extra height below the notch for the charging moment or a notice's card.
    var meterHeight: CGFloat {
        switch current?.kind {
        case .charging: return 34
        case .lowBattery: return IslandLayout.noticeStageHeight
        case .meetingReminder: return IslandLayout.reminderStageHeight
        case .audioDevice: return IslandLayout.deviceStageHeight
        case .agentApproval: return IslandLayout.approvalStageHeight
        case .notification: return IslandLayout.notificationStageHeight
        case .recorder(let notice): return notice.stageHeight
        // Toasts are never `current`: they have the band at the island's base.
        case .taskDue, .agentFinished, .copied, .keepAwake, .volume, .brightness, nil: return 0
        }
    }

    /// `confirming` a click made inside the island (a clipboard row copied again) is shown
    /// whatever the settings say about announcing that kind from outside.
    func post(_ kind: ActivityKind, confirming: Bool = false) {
        guard confirming || isAllowed(kind) else { return }
        if kind.isToast {
            showToast(kind)
            return
        }
        guard current?.kind != kind, !queue.contains(kind), queue.count < maxQueued else { return }
        queue.append(kind)
        // While an activity is showing (or in the gap after one), the timer chain picks this up.
        if current == nil && pendingWork == nil {
            showNext()
        }
    }

    private func showNext() {
        guard !queue.isEmpty else { return }
        let kind = queue.removeFirst()
        // Asked again: a call may have been answered, or a setting turned off, while it waited.
        guard isAllowed(kind) else { return showNext() }
        let next = TransientActivity(kind: kind)
        pointerInside = false
        Motion.perform(next.kind.isNotice ? Motion.notice : Motion.islandGrow) {
            current = next
        }
        schedule(after: duration(of: next.kind)) { [weak self] in self?.hideCurrent() }
    }

    private func duration(of kind: ActivityKind) -> TimeInterval {
        switch kind {
        case .lowBattery(_, .off): return noticeDuration
        case .lowBattery(_, .approving), .lowBattery(_, .requested): return lowPowerWait
        case .meetingReminder(let meeting):
            // Until it can no longer be joined.
            let closes = min(meeting.end, meeting.start.addingTimeInterval(CalendarService.meetingGrace))
            return max(closes.timeIntervalSinceNow, displayDuration)
        case .audioDevice: return deviceDuration
        case .notification: return noticeDuration
        case .agentApproval(let approval): return max(approval.expires.timeIntervalSinceNow, 1)
        case .recorder(let notice): return notice.duration
        default: return displayDuration
        }
    }

    /// The pointer moved, in or out of the island. A notice that can be clicked stays while the
    /// pointer is on it, and for a moment after it leaves.
    func pointerMoved(inside: Bool) {
        guard let kind = current?.kind, kind.isClickable, !kind.waitsForAnswer, inside != pointerInside else { return }
        pointerInside = inside
        if inside {
            pendingWork?.cancel()
            pendingWork = nil
        } else {
            schedule(after: noticeLinger) { [weak self] in self?.hideCurrent() }
        }
    }

    /// The low-battery notice was clicked and System Settings is opening (`mode` says for what):
    /// the notice waits for Low Power Mode to come on.
    func awaitLowPowerMode(_ mode: LowPowerMode) {
        guard let showing = current, case .lowBattery(let level, let shown) = showing.kind,
              shown != .on, shown != mode else { return }
        replace(showing, with: .lowBattery(level: level, lowPowerMode: mode))
        schedule(after: lowPowerWait) { [weak self] in self?.hideCurrent() }
    }

    /// Low Power Mode came on: a low-battery notice on screen turns gold, then leaves.
    func lowPowerModeTurnedOn() {
        guard let showing = current, case .lowBattery(let level, let mode) = showing.kind, mode != .on else { return }
        replace(showing, with: .lowBattery(level: level, lowPowerMode: .on))
        schedule(after: displayDuration) { [weak self] in self?.hideCurrent() }
    }

    /// Something an activity shows arrived late (a device's battery): the activity takes it in
    /// place if it is on screen, keeping its time there, or in the queue if it is waiting.
    func update(_ old: ActivityKind, to new: ActivityKind) {
        if let showing = current, showing.kind == old {
            replace(showing, with: new)
        } else if let index = queue.firstIndex(of: old) {
            queue[index] = new
        }
    }

    /// Something no longer needs showing (an agent's request answered on the Agents page or
    /// expired): it leaves the notch, or the queue.
    func withdraw(_ kind: ActivityKind) {
        queue.removeAll { $0 == kind }
        if current?.kind == kind { hideCurrent() }
    }

    /// One of the meeting reminder's buttons was clicked: it leaves.
    func reminderAnswered() {
        guard current?.kind.waitsForAnswer == true else { return }
        hideCurrent()
    }

    /// Changes what the activity on screen says, in place (same id, so its view updates rather
    /// than leaving and arriving).
    private func replace(_ showing: TransientActivity, with kind: ActivityKind) {
        pointerInside = false
        Motion.perform(Motion.notice) {
            current = TransientActivity(id: showing.id, kind: kind)
        }
    }

    /// Toasts are the user's own action, so they show at once and update in place while a key
    /// is held (or copies follow each other). A different toast takes the band over from the one
    /// showing; the band itself stays, so the island resizes once for the lot. Whatever else the
    /// island is showing carries on above the band, untouched.
    private func showToast(_ kind: ActivityKind) {
        if let showing = toast, showing.kind.isSameToast(as: kind) {
            toast = TransientActivity(id: showing.id, kind: kind)  // same id: the view updates in place
        } else {
            Motion.perform(Motion.toast) {
                toast = TransientActivity(kind: kind)
            }
        }
        toastWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.hideToast() }
        }
        toastWork = work
        var duration = toastDuration
        if case .copied = kind { duration = copiedDuration }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    /// A toast leaves the way it came, on the same spring.
    private func hideToast() {
        toastWork = nil
        Motion.performShrink(Motion.toast) {
            toast = nil
        }
    }

    /// A notice leaves as it came: blurring out while the island closes, on the same spring.
    private func hideCurrent() {
        pointerInside = false
        let notice = current?.kind.isNotice == true
        Motion.performShrink(notice ? Motion.notice : Motion.islandShrink) {
            current = nil
        }
        schedule(after: notice ? Motion.Duration.notice : Motion.islandShrinkSettle) { [weak self] in
            self?.showNext()
        }
    }

    private func schedule(after delay: TimeInterval, _ action: @escaping @MainActor () -> Void) {
        pendingWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.pendingWork = nil
                action()
            }
        }
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }
}

extension ActivityKind {
    /// The kind's name without what it carries: "volume", "copied", "meetingReminder"…
    var traceName: String {
        switch self {
        case .charging: return "charging"
        case .lowBattery: return "lowBattery"
        case .audioDevice: return "audioDevice"
        case .volume: return "volume"
        case .brightness: return "brightness"
        case .taskDue: return "taskDue"
        case .meetingReminder: return "meetingReminder"
        case .copied: return "copied"
        case .keepAwake: return "keepAwake"
        case .agentApproval: return "agentApproval"
        case .agentFinished: return "agentFinished"
        case .notification: return "notification"
        case .recorder: return "recorder"
        }
    }
}

#if DEBUG
extension ActivityCenter {
    /// Continuity tests: nothing showing, nothing waiting.
    func testClear() {
        pendingWork?.cancel()
        pendingWork = nil
        queue = []
        pointerInside = false
        current = nil
        toastWork?.cancel()
        toastWork = nil
        toast = nil
    }
}
#endif
