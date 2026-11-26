#if DEBUG
import AppKit
import Combine
import SwiftUI

/// Reduce Motion for the views, as the cell under test wants it.
@MainActor
final class ContinuityEnvironment: ObservableObject {
    static let shared = ContinuityEnvironment()
    @Published var reduceMotion = false
}

/// Applied to the island's root view: in the continuity suite's test mode the views read the
/// cell's Reduce Motion, not the system's. Outside it, nothing changes.
struct ContinuityEnvironmentModifier: ViewModifier {
    @ObservedObject private var environment = ContinuityEnvironment.shared

    func body(content: Content) -> some View {
        if Continuity.isActive {
            content.environment(\._accessibilityReduceMotion, environment.reduceMotion)
        } else {
            content
        }
    }
}

/// Runs continuity cells on the real island: puts it in a cell's starting state with made-up
/// data, fires the cell's triggers on exact frames, and saves the motion trace
/// (`docs/continuity/matrix.md` says what each cell expects; `scripts/continuity.sh` runs and
/// checks them all).
@MainActor
final class ContinuityRunner {
    private let controller: NotchWindowController
    private var model: NotchViewModel { controller.model }
    private var busy = false

    /// Where traces go unless a run names a folder.
    static var defaultFolder: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("app.topsail.continuity/traces", isDirectory: true)
    }

    init(controller: NotchWindowController) {
        self.controller = controller
        let tracer = MotionTracer.shared
        tracer.host = controller.window?.contentView
        tracer.state = { [weak controller] in controller?.model.traceState ?? [:] }
        applyBaseline()
    }

    /// `--continuity-list <file>` writes every cell's description; `--continuity-run <ids>` runs
    /// cells (`all`, or ids and `prefix*` patterns separated by commas) into `--continuity-out`,
    /// and `--continuity-exit` quits afterwards.
    func handleLaunchArguments() {
        if let path = Continuity.argument("--continuity-list") {
            let all = ContinuityCells.all.map { $0.header(notch: model.notchSize, build: Self.build) }
            let data = try? JSONSerialization.data(withJSONObject: all, options: [.prettyPrinted, .sortedKeys])
            try? data?.write(to: URL(fileURLWithPath: path))
        }
        guard let pattern = Continuity.argument("--continuity-run") else {
            if CommandLine.arguments.contains("--continuity-exit") { NSApp.terminate(nil) }
            return
        }
        let folder = Continuity.argument("--continuity-out").map { URL(fileURLWithPath: $0, isDirectory: true) }
        let exits = CommandLine.arguments.contains("--continuity-exit")
        Task {
            // The island settles on the notch before the first cell.
            try? await Task.sleep(for: .milliseconds(800))
            await run(matching: pattern, into: folder ?? Self.defaultFolder)
            if exits { NSApp.terminate(nil) }
        }
    }

    /// `topsail://test/<cell-id>` (or `all`, or a `prefix*`).
    func run(route: String) {
        Task { await run(matching: route, into: Self.defaultFolder) }
    }

    func run(matching pattern: String, into folder: URL) async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let cells = ContinuityCells.matching(pattern)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (index, cell) in cells.enumerated() {
            let lines = await run(cell)
            let file = folder.appendingPathComponent(cell.id + ".jsonl")
            try? (lines.joined(separator: "\n") + "\n").write(to: file, atomically: true, encoding: .utf8)
            let progress = "\(index + 1)/\(cells.count) \(cell.id)\n"
            try? progress.write(to: folder.appendingPathComponent("progress.txt"), atomically: true, encoding: .utf8)
        }
        reset()
        Continuity.settingUp = false
        try? "done \(cells.count)\n".write(to: folder.appendingPathComponent("done.txt"), atomically: true, encoding: .utf8)
    }

    private static var build: String {
        #if CONTINUITY_OPTIMIZED
        return "release"
        #else
        return "debug"
        #endif
    }

    // MARK: One cell

    private func run(_ cell: ContinuityCell) async -> [String] {
        Continuity.settingUp = true
        reset()
        try? await Task.sleep(for: .milliseconds(380))
        prepare(cell.start)
        try? await Task.sleep(for: .milliseconds(200))
        place(cell.start)
        try? await Task.sleep(for: .milliseconds(cell.start.settle))
        Continuity.settingUp = false

        let steps = cell.steps.map { step in
            MotionTracer.Step(at: step.at, label: step.trigger.label) { [weak self] in self?.fire(step.trigger) }
        }
        let header = cell.header(notch: model.notchSize, build: Self.build)
        let data = (try? JSONSerialization.data(withJSONObject: header, options: [.sortedKeys])) ?? Data()
        MotionTracer.shared.begin(header: String(decoding: data, as: UTF8.self), steps: steps)
        let length = (cell.steps.map(\.at).max() ?? 0) + cell.tail
        try? await Task.sleep(for: .milliseconds(Int(length)))
        return MotionTracer.shared.end()
    }

    // MARK: Starting states

    /// Preferences every cell starts from: quiet, with Keep Awake and the teleprompter on.
    private func applyBaseline() {
        let settings = model.settings
        settings.hapticFeedback = false
        settings.pondPassingKoi = false
        settings.hideSystemVolumeHUD = false
        settings.teleprompterScript = Fixtures.script
        settings.teleprompterHeight = Double(IslandLayout.teleprompterHeight)
        settings.notificationApps = [Fixtures.notification.bundleID]
        settings.setEnabled(.keepAwake, true)
        settings.setEnabled(.teleprompter, true)
    }

    /// Back to a closed, quiet island: nothing playing, nothing showing, nothing pending.
    private func reset() {
        Continuity.reduceMotion = false
        ContinuityEnvironment.shared.reduceMotion = false
        let features = model.features
        features.teleprompter.stop()
        features.recorder.preview("recording-idle")
        features.keepAwake.turnOff()
        features.agents.setFixture(sessions: [], approvals: [])
        model.nowPlaying.setFixture(playing: nil)
        model.calendar.setFixture(events: Fixtures.events, imminent: nil)
        model.clipboard.setFixture(texts: Fixtures.copies)
        model.testReset()
        model.testCopied(ago: nil)
        model.activities.testClear()
        controller.reposition()
        let settings = model.settings
        settings.teleprompterHeight = Double(IslandLayout.teleprompterHeight)
    }

    /// The data behind a starting state: which pages exist, what is playing, what is going on.
    private func prepare(_ start: ContinuityCell.Start) {
        Continuity.reduceMotion = start.reduceMotion
        ContinuityEnvironment.shared.reduceMotion = start.reduceMotion

        let settings = model.settings
        let all = start.pages == .all
        settings.showCalendar = true
        settings.showSystemPage = true
        settings.showClipboard = true
        settings.setEnabled(.pond, all)
        settings.setEnabled(.apps, all)
        settings.setEnabled(.shelf, all)
        settings.setEnabled(.agents, all || start.flags.contains(.agent) || start.needs.contains(.agents))
        settings.setEnabled(.recorder, all || start.flags.contains(.recording) || start.needs.contains(.recorder))
        settings.setEnabled(.notifications, true)
        model.linear.setFixture(all ? Fixtures.linear : nil)

        switch start.music {
        case .off: model.nowPlaying.setFixture(playing: nil)
        case .playing: model.nowPlaying.setFixture(playing: true)
        case .paused: model.nowPlaying.setFixture(playing: false)
        }
        if start.flags.contains(.recording) { model.features.recorder.preview("recording") }
        if start.flags.contains(.agent) {
            model.features.agents.setFixture(sessions: [Fixtures.workingSession], approvals: [])
        }
        if start.flags.contains(.meeting) {
            let meeting = Fixtures.meeting(inMinutes: 8)
            model.calendar.setFixture(events: [meeting] + Fixtures.events.prefix(1), imminent: meeting)
        }
    }

    /// Where the island starts: closed, leaning, open on a page, or holding the teleprompter;
    /// then whatever is on screen at the start (a koi, a charger just connected, a notice).
    private func place(_ start: ContinuityCell.Start) {
        switch start.island {
        case .closed:
            break
        case .leaning:
            model.testPointer(model.testPointNear)
        case .open(let page):
            Continuity.pointer = model.testPointInside
            model.expand()
            model.show(page)
        case .teleprompter:
            Continuity.pointer = model.testPointInside
            model.startTeleprompter()
        }
        if start.flags.contains(.koi) { model.startKoiPass(first: true) }
        if start.flags.contains(.charging) { model.activities.post(.charging(level: 80)) }
        if start.flags.contains(.lowBattery) { model.activities.post(.lowBattery(level: 20, lowPowerMode: .off)) }
    }

    // MARK: Triggers

    private func fire(_ trigger: ContinuityCell.Trigger) {
        let activities = model.activities
        switch trigger {
        case .near: model.testPointer(model.testPointNear)
        case .over: model.testPointer(model.testPointOver)
        case .inside: model.testPointer(model.testPointInside)
        case .away: model.testPointer(nil)
        case .page(let page): model.show(page)
        case .click(let name): click(name)
        case .keepAwake: model.toggleKeepAwake()
        case .copy: model.clipboard.fixtureCopy(Fixtures.freshCopy)
        case .copied(let ago): model.testCopied(ago: ago)
        case .post(let name):
            if let kind = Fixtures.activity(name, hub: model.features.agents) { activities.post(kind) }
        case .volume(let level): activities.post(.volume(level: level, muted: false))
        case .mute: activities.post(.volume(level: 0.5, muted: true))
        case .brightness(let level): activities.post(.brightness(level: level))
        case .music(let music):
            model.nowPlaying.setFixture(playing: music == .off ? nil : music == .playing)
        case .recording(let on): model.features.recorder.preview(on ? "recording" : "recording-idle")
        case .agent(let on):
            model.features.agents.setFixture(sessions: on ? [Fixtures.workingSession] : [], approvals: [])
        case .meeting(let minutes):
            let meeting = minutes.map(Fixtures.meeting(inMinutes:))
            model.calendar.setFixture(events: (meeting.map { [$0] } ?? []) + Fixtures.events.prefix(1), imminent:
                                        meeting.flatMap { CalendarService.isJoinable($0) ? $0 : nil })
        case .koi(let on): if on { model.startKoiPass(first: true) } else { model.endKoiPass() }
        case .teleStart: model.startTeleprompter()
        case .teleStop: model.features.teleprompter.stop()
        case .teleDrag(let translation): model.dragTeleprompter(by: translation)
        case .teleRelease(let predicted): model.endTeleprompterDrag(predicted: predicted)
        case .display(let size):
            let notch = model.notchRect
            model.update(notchRect: CGRect(x: notch.midX - size.width / 2, y: notch.maxY - size.height,
                                           width: size.width, height: size.height))
        case .answerMeeting:
            if case .meetingReminder(let meeting) = activities.current?.kind { model.answerMeeting(meeting, .ignore) }
        case .answerAgent:
            // Answered: the request goes, the agent carries on working.
            if case .agentApproval(let approval) = activities.current?.kind {
                model.features.agents.setFixture(sessions: [Fixtures.workingSession], approvals: [])
                activities.withdraw(.agentApproval(approval))
            }
        case .clipboardMode(let shelf): model.showClipboardMode(shelf ? .shelf : .clipboard)
        }
    }

    /// A real click on a traced control: mouse down and up through the window, as from the mouse.
    private func click(_ name: String) {
        guard let window = controller.window, let point = MotionTracer.shared.windowCentre(of: name) else { return }
        func send(_ type: NSEvent.EventType) {
            guard let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                                                 timestamp: ProcessInfo.processInfo.systemUptime,
                                                 windowNumber: window.windowNumber, context: nil, eventNumber: 0,
                                                 clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0) else { return }
            window.sendEvent(event)
        }
        send(.leftMouseDown)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { send(.leftMouseUp) }
    }
}

// MARK: - Made-up data

enum Fixtures {
    static let copies = ["Harbour lights at dusk", "https://example.com/tide-tables", "Pack the sails before noon"]
    static let freshCopy = "Low tide at six, high tide at noon"
    static let script = """
    Good morning, everyone. This is a test script for the teleprompter. It runs for a few lines so \
    there is something to scroll. The harbour opens at six. The first boat leaves at seven. Bring a \
    coat, the wind picks up after noon. That is all for today.
    """

    static let events: [UpcomingEvent] = {
        let now = Date()
        return [
            UpcomingEvent(id: "fixture-1", title: "Team sync", start: now.addingTimeInterval(2 * 3600),
                          end: now.addingTimeInterval(2.5 * 3600), isAllDay: false, color: .blue, joinURL: nil),
            UpcomingEvent(id: "fixture-2", title: "Sail repair workshop", start: now.addingTimeInterval(5 * 3600),
                          end: now.addingTimeInterval(6 * 3600), isAllDay: false, color: .orange, joinURL: nil),
        ]
    }()

    nonisolated(unsafe) private static var meetingCount = 0

    static func meeting(inMinutes minutes: Double) -> UpcomingEvent {
        let start = Date().addingTimeInterval(minutes * 60)
        // A new call each time: one that was answered is never offered again.
        meetingCount += 1
        return UpcomingEvent(id: "fixture-meeting-\(meetingCount)", title: "Design review", start: start,
                             end: start.addingTimeInterval(30 * 60), isAllDay: false, color: .purple,
                             joinURL: URL(string: "https://example.com/call"))
    }

    static let workingSession = AgentSession(id: "fixture", agent: .claude, project: "harbour",
                                             status: .working("Running tests"), since: Date(),
                                             startedAt: Date().addingTimeInterval(-120))

    static let notification = MirroredNotification(id: 1, bundleID: "com.apple.mail", appName: "Mail",
                                                   title: "Harbour Office", body: "Tide tables for the week are attached.")

    static let linear: LinearSnapshot = {
        func issue(_ number: Int, _ title: String, _ state: String, _ type: String, _ priority: Int) -> LinearIssue {
            LinearIssue(id: "fixture-\(number)", identifier: "TOP-\(number)", title: title,
                        url: URL(string: "https://linear.app/example/issue/TOP-\(number)")!, priority: priority,
                        stateName: state, stateType: type, stateColor: type == "started" ? "#f2c94c" : "#bec2c8",
                        statePosition: Double(number), teamKey: "TOP", dueDate: nil, inCurrentCycle: false,
                        inUpcomingCycle: false)
        }
        return LinearSnapshot(viewerName: "Test", issues: [
            issue(1, "Check the rigging", "In Progress", "started", 2),
            issue(2, "Order new charts", "Todo", "unstarted", 3),
            issue(3, "Paint the hull", "Todo", "unstarted", 4),
        ], cycle: nil, fetchedAt: Date())
    }()

    /// An activity by its kind's name, carrying made-up contents.
    @MainActor static func activity(_ name: String, hub: AgentHub) -> ActivityKind? {
        switch name {
        case "charging": return .charging(level: 80)
        case "lowBattery": return .lowBattery(level: 20, lowPowerMode: .off)
        case "audioDevice":
            return .audioDevice(name: "AirPods Pro", battery: DeviceBattery(left: 80, right: 75, chargingCase: 60))
        case "taskDue": return .taskDue(title: "Check the rigging", overdue: false)
        case "meetingReminder": return .meetingReminder(meeting(inMinutes: 1))
        case "agentApproval":
            let approval = AgentApproval(id: UUID(), agent: .claude, project: "harbour", verb: "run",
                                         detail: "swift test", expires: Date().addingTimeInterval(60))
            hub.setFixture(sessions: [workingSession], approvals: [approval])
            return .agentApproval(approval)
        case "agentFinished": return .agentFinished(agent: .claude, project: "harbour")
        case "notification": return .notification(notification)
        case "recorder":
            return .recorder(.saved(SavedRecording(url: RecorderSettings.defaultFolder.appending(path: "Screen recording.mov"),
                                                   kind: .screen, duration: 154)))
        case "copied": return .copied(snippet: freshCopy)
        case "keepAwake": return .keepAwake(on: true)
        case "volume": return .volume(level: 0.6, muted: false)
        case "brightness": return .brightness(level: 0.7)
        default: return nil
        }
    }
}
#endif
