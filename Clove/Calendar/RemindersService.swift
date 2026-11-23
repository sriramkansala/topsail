import AppKit
import EventKit
import SwiftUI

/// An incomplete reminder, as the island lists it.
struct ReminderItem: Identifiable, Equatable {
    let id: String
    let title: String
    let due: Date?
    let color: Color

    func isOverdue(at now: Date = Date()) -> Bool {
        guard let due else { return false }
        return due < now
    }
}

/// The user's incomplete Apple Reminders, soonest due first: ticked off and added from the
/// island. Access is asked for only when the user turns Reminders on (Settings › Features) or
/// taps "Show reminders" in the island.
@MainActor
final class RemindersService: ObservableObject {
    enum Access { case notDetermined, granted, denied }

    @Published private(set) var access: Access
    /// Every incomplete reminder, in the order shown.
    @Published private(set) var reminders: [ReminderItem] = []

    private let store = EKEventStore()
    private var observer: NSObjectProtocol?
    private var running = false

    init() {
        access = Self.currentAccess()
    }

    /// Starts listing (when the feature is turned on). Asks for access the first time.
    func start() {
        guard !running else { return }
        running = true
        switch access {
        case .granted: beginUpdating()
        case .notDetermined: requestAccess()
        case .denied: break
        }
    }

    func stop() {
        running = false
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        reminders = []
    }

    func requestAccess() {
        guard access == .notDetermined else { return }
        Task {
            let granted = (try? await store.requestFullAccessToReminders()) ?? false
            access = granted ? .granted : .denied
            if granted, running { beginUpdating() }
        }
    }

    func refresh() {
        guard access == .granted, running else { return }
        let predicate = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: nil, calendars: nil)
        store.fetchReminders(matching: predicate) { [weak self] fetched in
            let items = (fetched ?? []).map { reminder in
                ReminderItem(id: reminder.calendarItemIdentifier,
                             title: reminder.title ?? "",
                             due: reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) },
                             color: Color(nsColor: reminder.calendar?.color ?? .systemOrange))
            }
            .sorted(by: Self.order)
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    if self?.reminders != items { self?.reminders = items }
                }
            }
        }
    }

    /// Ticks a reminder off.
    func complete(_ item: ReminderItem) {
        guard let reminder = store.calendarItem(withIdentifier: item.id) as? EKReminder else { return }
        reminder.isCompleted = true
        do {
            try store.save(reminder, commit: true)
            reminders.removeAll { $0.id == item.id }
        } catch {
            NSLog("Clove: could not complete a reminder: \(error.localizedDescription)")
        }
    }

    /// Adds a reminder to the default list.
    func add(_ title: String) {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let list = store.defaultCalendarForNewReminders() else { return }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = list
        do {
            try store.save(reminder, commit: true)
            refresh()
        } catch {
            NSLog("Clove: could not add a reminder: \(error.localizedDescription)")
        }
    }

    /// Opens the Reminders app, for everything past what the island lists.
    func openApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.reminders") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    private func beginUpdating() {
        refresh()
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// Due ones first, soonest first; then the rest as Reminders keeps them.
    private nonisolated static func order(_ a: ReminderItem, _ b: ReminderItem) -> Bool {
        switch (a.due, b.due) {
        case let (x?, y?): return x < y
        case (.some, nil): return true
        case (nil, .some): return false
        case (nil, nil): return false
        }
    }

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .reminder) {
        case .fullAccess, .authorized: return .granted
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }
}
