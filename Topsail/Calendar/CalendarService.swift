import AppKit
import EventKit
import SwiftUI

struct UpcomingEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: Color
    /// Video-call link found in the event (Zoom, Meet, Teams, Webex, FaceTime, …), if any.
    let joinURL: URL?

    var isMeeting: Bool { joinURL != nil }
}

/// Upcoming events from the user's calendars (now until the end of tomorrow, at most `IslandLayout.maxEvents`).
/// Access is only requested from a button in the expanded island, never at launch.
@MainActor
final class CalendarService: ObservableObject {
    enum Access { case notDetermined, granted, denied }

    @Published private(set) var access: Access
    @Published private(set) var events: [UpcomingEvent] = []
    /// The next meeting with a join link, from `meetingLeadTime` before it starts until
    /// `meetingGrace` after; drives the "meeting soon" activity beside the notch.
    @Published private(set) var imminentMeeting: UpcomingEvent?

    static let meetingLeadTime: TimeInterval = 10 * 60
    static let meetingGrace: TimeInterval = 10 * 60
    /// The reminder card (Join, Ignore, Remind me in 5 min) drops this long before a call starts.
    static let reminderLeadTime: TimeInterval = 60
    static let snoozeInterval: TimeInterval = 5 * 60

    /// A call's reminder is due: shown once as it starts, and again after each snooze. Set after
    /// launch, by when the island exists; a reminder already due then is sent at once.
    var onReminder: ((UpcomingEvent) -> Void)? {
        didSet { updateImminentMeeting() }
    }
    /// A call was joined from its reminder (the recorder may offer to record it).
    var onJoin: ((UpcomingEvent) -> Void)?
    /// Calls whose reminder has been shown, and calls the user joined or ignored (no more
    /// reminders, nothing beside the notch). Keyed by event id, which includes the start time.
    private var reminded: Set<String> = []
    private var answered: Set<String> = []
    private var snoozedUntil: [String: Date] = [:]

    /// Every upcoming event in the window, not just the ones shown: a meeting can be imminent
    /// while earlier, non-meeting events fill the visible rows.
    private var upcoming: [UpcomingEvent] = []
    private var clockTimer: Timer?

    private let store = EKEventStore()
    private var refreshTimer: Timer?
    private var storeObserver: NSObjectProtocol?

    init() {
        #if DEBUG
        if Continuity.isActive {  // continuity tests: fixture data only
            access = .granted
            return
        }
        #endif
        access = Self.currentAccess()
        if access == .granted {
            startUpdating()
        }
    }

    func requestAccess() {
        guard access == .notDetermined else { return }
        Task {
            let granted = (try? await store.requestFullAccessToEvents()) ?? false
            access = granted ? .granted : .denied
            if granted {
                startUpdating()
            }
        }
    }

    func refresh() {
        #if DEBUG
        if Continuity.isActive { return }  // continuity tests: fixture data only
        #endif
        guard access == .granted else { return }
        let now = Date()
        let calendar = Calendar.current
        guard let end = calendar.date(byAdding: .day, value: 2, to: calendar.startOfDay(for: now)) else { return }

        // The predicate also returns events already in progress at `now`.
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        upcoming = store.events(matching: predicate)
            .filter { $0.endDate > now && $0.status != .canceled }
            .sorted { $0.startDate < $1.startDate }
            .map { event in
                UpcomingEvent(
                    id: "\(event.calendarItemIdentifier)-\(event.startDate.timeIntervalSince1970)",
                    title: event.title ?? "",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    color: Color(nsColor: event.calendar.color),
                    joinURL: event.isAllDay ? nil : MeetingLink.find(in: event)
                )
            }
        // Timed events first: all-day ones start at midnight and would otherwise take the rows
        // a meeting needs.
        let visible = Array((upcoming.filter { !$0.isAllDay } + upcoming.filter(\.isAllDay))
            .prefix(IslandLayout.maxEvents))
        if visible != events {
            events = visible
        }
        // Forget calls that have ended.
        let ids = Set(upcoming.map(\.id))
        reminded.formIntersection(ids)
        answered.formIntersection(ids)
        snoozedUntil = snoozedUntil.filter { ids.contains($0.key) }
        updateImminentMeeting()
    }

    /// Whether `event` is close enough to its start (or just started) to offer Join.
    static func isJoinable(_ event: UpcomingEvent, at date: Date = Date()) -> Bool {
        guard event.isMeeting else { return false }
        let untilStart = event.start.timeIntervalSince(date)
        return untilStart <= meetingLeadTime && date < event.end && -untilStart <= meetingGrace
    }

    func join(_ event: UpcomingEvent) {
        guard let url = event.joinURL else { return }
        NSWorkspace.shared.open(url)
        answer(event)
        onJoin?(event)
    }

    /// The user isn't taking this call: no more reminders, and it leaves the notch.
    func ignore(_ event: UpcomingEvent) {
        answer(event)
    }

    /// "Remind me in 5 min": the card comes back then, while the call can still be joined.
    func snooze(_ event: UpcomingEvent) {
        snoozedUntil[event.id] = Date().addingTimeInterval(Self.snoozeInterval)
    }

    /// Whether `event`'s reminder should still be shown: it can be joined, and the user hasn't
    /// answered it or put it off.
    func isReminderDue(_ event: UpcomingEvent, at date: Date = Date()) -> Bool {
        guard Self.isJoinable(event, at: date), !answered.contains(event.id) else { return false }
        return snoozedUntil[event.id].map { date >= $0 } ?? true
    }

    private func answer(_ event: UpcomingEvent) {
        answered.insert(event.id)
        snoozedUntil[event.id] = nil
        updateImminentMeeting()
    }

    /// Cheap and frequent: re-evaluates the already-fetched events against the clock, and posts
    /// any reminder that has come due.
    private func updateImminentMeeting() {
        let now = Date()
        let next = upcoming.first { Self.isJoinable($0, at: now) && !answered.contains($0.id) }
        if next != imminentMeeting {
            imminentMeeting = next
        }

        // Nothing is marked as reminded until there is someone to remind.
        guard let onReminder else { return }
        for event in upcoming where isReminderDue(event, at: now) {
            if snoozedUntil[event.id] != nil {
                snoozedUntil[event.id] = nil
                onReminder(event)
            } else if !reminded.contains(event.id), event.start.timeIntervalSince(now) <= Self.reminderLeadTime {
                reminded.insert(event.id)
                onReminder(event)
            }
        }
    }

    private func startUpdating() {
        refresh()
        storeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        let timer = Timer(timeInterval: 300, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer

        // The meeting window opens and closes with the clock, between fetches, and reminders
        // come due; a few seconds' slack is fine for both.
        let clock = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateImminentMeeting() }
        }
        RunLoop.main.add(clock, forMode: .common)
        clockTimer = clock
    }

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied  // denied, restricted, or write-only
        }
    }
}

#if DEBUG
extension CalendarService {
    /// Continuity tests: made-up events, and whether one of them is a call about to start.
    func setFixture(events: [UpcomingEvent], imminent: UpcomingEvent?) {
        upcoming = events
        self.events = Array(events.prefix(IslandLayout.maxEvents))
        imminentMeeting = imminent
    }
}
#endif
