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
        case .lowBattery, .meetingReminder, .audioDevice: return true
        default: return false
        }
    }

    var isClickable: Bool {
        switch self {
        case .lowBattery(_, .off), .meetingReminder: return true
        default: return false
        }
    }

    /// The meeting reminder stays until one of its buttons is clicked (or the call can no longer
    /// be joined), wherever the pointer goes.
    var waitsForAnswer: Bool {
        if case .meetingReminder = self { return true }
        return false
    }

    /// Levels the user is adjusting right now (volume, brightness): shown at once, updated in place.
    var isLiveLevel: Bool {
        switch self {
        case .volume, .brightness: return true
        case .charging, .lowBattery, .audioDevice, .taskDue, .meetingReminder: return false
        }
    }

    func isSameLiveLevel(as other: ActivityKind) -> Bool {
        switch (self, other) {
        case (.volume, .volume), (.brightness, .brightness): return true
        default: return false
        }
    }
}

struct TransientActivity: Identifiable, Equatable {
    var id = UUID()
    let kind: ActivityKind
}

/// Queues short "live activities" that are shown beside the notch for a few seconds,
/// one at a time, while the island is collapsed.
@MainActor
final class ActivityCenter: ObservableObject {
    @Published private(set) var current: TransientActivity?
    /// Settings filter; activities it rejects are dropped.
    var isAllowed: (ActivityKind) -> Bool = { _ in true }

    private var queue: [ActivityKind] = []
    private var pendingWork: DispatchWorkItem?
    private let displayDuration: TimeInterval = 3
    private let levelDisplayDuration: TimeInterval = 1.5
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

    /// Extra height below the notch for the level meter drawn along the island's bottom edge, for
    /// the charging moment, or for a notice's card.
    var meterHeight: CGFloat {
        switch current?.kind {
        case .charging: return 34
        case .lowBattery: return IslandLayout.noticeStageHeight
        case .meetingReminder: return IslandLayout.reminderStageHeight
        case .audioDevice: return IslandLayout.deviceStageHeight
        case .volume, .brightness: return 8
        case .taskDue, nil: return 0
        }
    }

    func post(_ kind: ActivityKind) {
        guard isAllowed(kind) else { return }
        if kind.isLiveLevel {
            showLevel(kind)
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

    /// Volume and brightness changes are the user's own action, so they show immediately and
    /// update in place while keys are held, instead of queueing one notification per key press.
    /// An activity they interrupt is shown again afterwards.
    private func showLevel(_ kind: ActivityKind) {
        if let showing = current, showing.kind.isSameLiveLevel(as: kind) {
            current = TransientActivity(id: showing.id, kind: kind)  // same id: the view updates, no cross-fade
        } else {
            // Resume an interrupted notification afterwards; a stale level is not worth repeating.
            if let showing = current, !showing.kind.isLiveLevel {
                queue.insert(showing.kind, at: 0)
            }
            pointerInside = false
            Motion.perform(Motion.islandGrow) {
                current = TransientActivity(kind: kind)
            }
        }
        schedule(after: levelDisplayDuration) { [weak self] in self?.hideCurrent() }
    }

    /// A notice leaves as it came: blurring out while the island closes, on the same spring.
    private func hideCurrent() {
        pointerInside = false
        let notice = current?.kind.isNotice == true
        Motion.perform(notice ? Motion.notice : Motion.islandShrink) {
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
