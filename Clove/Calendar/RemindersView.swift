import SwiftUI

/// The calendar tab: upcoming events, Apple Reminders, or both with a switch above them.
struct CalendarTabView: View {
    @ObservedObject var model: NotchViewModel
    @ObservedObject var calendar: CalendarService
    @ObservedObject var reminders: RemindersService

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: IslandLayout.pageSwitchGap) {
            if model.calendarModes.count > 1 {
                PageSwitch(options: [
                    .init(title: "Events", selected: model.visibleCalendarMode == .events) {
                        model.showCalendarMode(.events)
                    },
                    .init(title: "Reminders", count: reminders.reminders.isEmpty ? nil : reminders.reminders.count,
                          selected: model.visibleCalendarMode == .reminders) {
                        model.showCalendarMode(.reminders)
                    },
                ])
            }
            ZStack(alignment: .top) {
                if model.visibleCalendarMode == .reminders {
                    RemindersView(reminders: reminders)
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                } else {
                    CalendarColumnView(calendar: calendar)
                        .transition(.contentMorph(reduceMotion: reduceMotion))
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
    }
}

/// Incomplete reminders, soonest due first: a circle to tick each off, its title, and when it's
/// due (red once overdue); then a field to add one. Past `IslandLayout.maxReminders`, a link
/// opens Reminders.
struct RemindersView: View {
    @ObservedObject var reminders: RemindersService

    @State private var draft = ""
    /// Ticked rows, which show their check for a moment before leaving.
    @State private var ticked: Set<String> = []

    var body: some View {
        switch reminders.access {
        case .notDetermined:
            Button(action: reminders.requestAccess) {
                MessageView(symbol: "checklist", text: "Show reminders")
            }
            .buttonStyle(.pressable(.subtle))
        case .denied:
            MessageView(symbol: "checklist", text: "Allow Clove under Privacy & Security › Reminders")
        case .granted:
            VStack(alignment: .leading, spacing: IslandLayout.remindersRowSpacing) {
                ForEach(reminders.reminders.prefix(IslandLayout.maxReminders)) { item in
                    ReminderRow(item: item, ticked: ticked.contains(item.id)) { tick(item) }
                }
                addRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var addRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.4))
                .frame(width: 16)
            TextField("New reminder", text: $draft)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5))
                .foregroundColor(.white)
                .onSubmit {
                    reminders.add(draft)
                    draft = ""
                }
            let more = reminders.reminders.count - IslandLayout.maxReminders
            if more > 0 {
                Button(action: reminders.openApp) {
                    Text("\(more) more")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.pressable(.normal, hoverWash: false))
                .help("Open Reminders")
            }
        }
        .frame(height: IslandLayout.remindersRowHeight)
    }

    private func tick(_ item: ReminderItem) {
        withAnimation(Motion.fast) { _ = ticked.insert(item.id) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(Motion.base) { reminders.complete(item) }
            ticked.remove(item.id)
        }
    }
}

/// One reminder: tick circle (in its list's colour), title, due.
private struct ReminderRow: View {
    let item: ReminderItem
    let ticked: Bool
    let tick: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: tick) {
                Image(systemName: ticked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundColor(ticked ? item.color : item.color.opacity(0.9))
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 16)
            }
            .buttonStyle(.pressable(.normal, hoverWash: false))
            .help("Mark as done")
            .accessibilityLabel("Mark \(item.title) as done")

            Text(item.title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundColor(.white.opacity(ticked ? 0.4 : 1))
                .strikethrough(ticked, color: .white.opacity(0.4))
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            if let due = item.due {
                TimelineView(.everyMinute) { context in
                    Text(Self.dueText(due, now: context.date))
                        .font(.system(size: 10.5).monospacedDigit())
                        .foregroundColor(item.isOverdue(at: context.date) ? .red : .white.opacity(0.45))
                }
            }
        }
        .frame(height: IslandLayout.remindersRowHeight)
    }

    /// "Today 17:00", "Tomorrow", "Mon 9:00", "12 Dec".
    static func dueText(_ due: Date, now: Date) -> String {
        let calendar = Calendar.current
        let hasTime = calendar.component(.hour, from: due) != 0 || calendar.component(.minute, from: due) != 0
        let time = due.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(due) { return hasTime ? time : String(localized: "Today") }
        if calendar.isDateInTomorrow(due) { return hasTime ? String(localized: "Tomorrow \(time)") : String(localized: "Tomorrow") }
        if calendar.isDateInYesterday(due) { return String(localized: "Yesterday") }
        if let days = calendar.dateComponents([.day], from: now, to: due).day, abs(days) < 7 {
            return due.formatted(.dateTime.weekday(.abbreviated)) + (hasTime ? " \(time)" : "")
        }
        return due.formatted(.dateTime.day().month(.abbreviated))
    }
}
