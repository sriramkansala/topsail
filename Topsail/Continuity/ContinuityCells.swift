#if DEBUG
import AppKit

/// One cell of the continuity matrix: a starting state, the triggers fired from it (milliseconds
/// after the trace starts) and what must be true afterwards. `scripts/continuity/check.py`
/// applies the rules that hold for every cell (no pops, no teleports, centre on the notch, radii
/// at rest, one resize per event…) and the cell's own expectations below.
struct ContinuityCell {
    typealias Page = NotchViewModel.ExpandedPage

    enum Island: Equatable {
        case closed
        /// Closed, with the pointer near enough to make it lean.
        case leaning
        case open(Page)
        case teleprompter
    }

    enum Music: String { case off, playing, paused }

    /// What else is going on at the start.
    enum Flag: String {
        case recording, agent, meeting, koi
        /// A charger was just connected: its moment is on screen.
        case charging
        /// The low-battery notice is on screen.
        case lowBattery
    }

    /// Which pages exist: the usual few (calendar, system, clipboard, and the player when
    /// something plays), or every page there is.
    enum Pages: String { case standard, all }

    /// A feature the cell's triggers need switched on.
    enum Need { case agents, recorder }

    struct Start {
        var island: Island = .closed
        var music: Music = .off
        var flags: Set<Flag> = []
        var pages: Pages = .standard
        var reduceMotion = false
        var needs: Set<Need> = []

        /// How long the state is left to settle before tracing, in milliseconds.
        var settle: Int { flags.contains(.charging) || flags.contains(.lowBattery) ? 1300 : 650 }

        var text: String {
            var parts: [String]
            switch island {
            case .closed: parts = ["closed"]
            case .leaning: parts = ["leaning"]
            case .open(let page): parts = ["open: \(page)"]
            case .teleprompter: parts = ["teleprompter"]
            }
            if music != .off { parts.append("music \(music.rawValue)") }
            parts += flags.map(\.rawValue).sorted()
            if pages == .all { parts.append("all pages") }
            if reduceMotion { parts.append("Reduce Motion") }
            return parts.joined(separator: " · ")
        }
    }

    enum Trigger {
        /// The pointer: beside the closed island, on it, inside the open one, far away.
        case near, over, inside, away
        /// A page picked from its tab.
        case page(Page)
        /// A real mouse click on a traced control.
        case click(String)
        /// The ☕ button.
        case keepAwake
        /// Something copied in another app.
        case copy
        /// The last copy was this many seconds ago (nil: never), with nothing shown.
        case copied(TimeInterval?)
        /// An activity, by its kind's name.
        case post(String)
        /// A volume or brightness key.
        case volume(Float), mute, brightness(Float)
        case music(Music), recording(Bool), agent(Bool)
        /// A call that many minutes away (nil: none).
        case meeting(Double?)
        case koi(Bool)
        case teleStart, teleStop
        /// The teleprompter's handle, dragged this far from where it was grabbed, then let go.
        case teleDrag(CGFloat), teleRelease(CGFloat)
        /// Another display took over: its notch (or menu bar) has this size.
        case display(CGSize)
        /// Ignore on the meeting reminder; the agent's request answered.
        case answerMeeting, answerAgent
        /// The clipboard page's Clipboard / Shelf switch.
        case clipboardMode(shelf: Bool)

        var label: String {
            switch self {
            case .near: return "pointer near"
            case .over: return "pointer on the island"
            case .inside: return "pointer inside"
            case .away: return "pointer away"
            case .page(let page): return "pick \(page)"
            case .click(let name): return "click \(name)"
            case .keepAwake: return "Keep Awake"
            case .copy: return "copy"
            case .copied(let ago): return ago.map { "copied \(Int($0)) s ago" } ?? "no copy"
            case .post(let name): return name
            case .volume(let level): return "volume \(Int(level * 100))"
            case .mute: return "mute"
            case .brightness(let level): return "brightness \(Int(level * 100))"
            case .music(let music): return "music \(music.rawValue)"
            case .recording(let on): return on ? "recording starts" : "recording stops"
            case .agent(let on): return on ? "agent starts" : "agent stops"
            case .meeting(let minutes): return minutes.map { "call in \(Int($0)) min" } ?? "no call"
            case .koi(let on): return on ? "koi starts" : "koi ends"
            case .teleStart: return "teleprompter starts"
            case .teleStop: return "teleprompter stops"
            case .teleDrag(let by): return "drag \(Int(by))"
            case .teleRelease(let predicted): return "let go \(Int(predicted))"
            case .display(let size): return "display \(Int(size.width))×\(Int(size.height))"
            case .answerMeeting: return "Ignore"
            case .answerAgent: return "answered"
            case .clipboardMode(let shelf): return shelf ? "pick Shelf" : "pick Clipboard"
            }
        }
    }

    struct Step {
        let at: Double
        let trigger: Trigger
    }

    struct Expect {
        /// The page showing (or last shown) at the end.
        var page: Page?
        /// "collapsed" or "expanded" at the end.
        var state: String?
        /// Toast kinds that must each show, in the base band.
        var toasts: [String] = []
        /// Notices and wing activities that must each show.
        var shows: [String] = []
        /// Elements that must at least be glimpsed (a toast replaced 200 ms after it arrived).
        var glimpses: [String] = []
        /// Elements that must never show.
        var never: [String] = []
        /// Nothing visible may change at all (a notice arriving while the island is open).
        var quiet = false
        /// Apart from the band at the base, nothing on screen may move or fade (a toast's promise).
        var still = false
    }

    let id: String
    let group: String
    let start: Start
    let steps: [Step]
    /// Milliseconds traced after the last trigger.
    let tail: Double
    let expect: Expect
    /// The expected result, in a line.
    let summary: String

    func header(notch: CGSize, build: String) -> [String: Any] {
        var expected: [String: Any] = ["toasts": expect.toasts, "shows": expect.shows, "never": expect.never,
                                       "glimpses": expect.glimpses,
                                       "quiet": expect.quiet, "still": expect.still]
        if let page = expect.page { expected["page"] = "\(page)" }
        if let state = expect.state { expected["state"] = state }
        return ["cell": id, "group": group, "start": start.text, "reduceMotion": start.reduceMotion,
                "steps": steps.map { [$0.at, $0.trigger.label] as [Any] }, "tail": tail, "expect": expected,
                "summary": summary, "notch": [notch.width, notch.height], "build": build,
                "band": IslandLayout.toastBandHeight]
    }
}

/// The matrix: every cell the suite runs. See `docs/continuity/matrix.md` for the states, the
/// triggers and why this set covers them.
enum ContinuityCells {
    typealias Cell = ContinuityCell
    typealias Start = ContinuityCell.Start
    typealias Trigger = ContinuityCell.Trigger
    typealias Expect = ContinuityCell.Expect
    typealias Page = ContinuityCell.Page

    static let all: [Cell] = hover + pages + toasts + activities + interruptions + keys + teleprompter
        + display + reduceMotion + arrivals + relevance

    /// `all`, an id, a `prefix*`, or several of those separated by commas.
    static func matching(_ pattern: String) -> [Cell] {
        if pattern == "all" { return all }
        let patterns = pattern.split(separator: ",").map(String.init)
        return all.filter { cell in
            patterns.contains { $0.hasSuffix("*") ? cell.id.hasPrefix(String($0.dropLast())) : cell.id == $0 }
        }
    }

    private static func cell(_ id: String, _ group: String, _ start: Start, _ steps: [(Double, Trigger)],
                             tail: Double = 1000, _ expect: Expect = Expect(), _ summary: String) -> Cell {
        Cell(id: id, group: group, start: start, steps: steps.map { ContinuityCell.Step(at: $0.0, trigger: $0.1) },
             tail: tail, expect: expect, summary: summary)
    }

    /// Time a toast of this kind is traced for: its whole life, in and out.
    private static func life(_ kind: String) -> Double { kind == "copied" ? 3900 : 2900 }

    private static func toastTrigger(_ kind: String) -> Trigger {
        switch kind {
        case "copied": return .copy
        case "keepAwake": return .keepAwake
        case "volume": return .volume(0.6)
        default: return .brightness(0.7)
        }
    }

    private static let toastKinds = ["copied", "keepAwake", "volume", "brightness"]

    /// The closed island's states by name: what is beside the notch.
    private static let closedStates: [(name: String, start: Start)] = [
        ("idle", Start()),
        ("music", Start(music: .playing)),
        ("recording", Start(flags: [.recording])),
        ("agent", Start(flags: [.agent])),
        ("meeting", Start(flags: [.meeting])),
        ("koi", Start(flags: [.koi])),
        ("music+recording", Start(music: .playing, flags: [.recording])),
        ("music+agent", Start(music: .playing, flags: [.agent])),
        ("music+meeting", Start(music: .playing, flags: [.meeting])),
    ]

    // MARK: Hover: the island opening and closing

    private static var hover: [Cell] {
        var cells: [Cell] = []
        let opensOn: [String: Page] = ["idle": .calendar, "music": .player, "recording": .recorder, "agent": .calendar,
                                       "meeting": .calendar, "koi": .calendar, "music+recording": .recorder,
                                       "music+agent": .player, "music+meeting": .calendar]
        for (name, start) in closedStates {
            let page = opensOn[name]!
            cells.append(cell("hover.\(name)", "Hover", start, [(250, .near), (400, .over), (1700, .away)], tail: 1200,
                              Expect(page: page, state: "collapsed"),
                              "Leans, opens on \(page) in one growth, then closes in one; what is beside the notch travels or fades, never pops."))
        }
        cells.append(cell("hover.charging", "Hover", Start(flags: [.charging]), [(250, .over), (1500, .away)], tail: 1200,
                          Expect(page: .calendar, state: "collapsed"),
                          "The charging moment gives way to the open island in one growth; closing returns to the notch."))
        cells.append(cell("hover.music-paused", "Hover", Start(music: .paused), [(250, .over), (1500, .away)], tail: 1200,
                          Expect(page: .player, state: "collapsed"),
                          "Paused music still opens on the player; the artwork travels both ways."))
        for (name, start) in [("idle", Start()), ("music", Start(music: .playing))] {
            cells.append(cell("lean.\(name)", "Hover", start, [(250, .near), (1100, .away)],
                              Expect(state: "collapsed"),
                              "The closed island leans 6 pt wider and 3 pt taller toward the pointer and settles back; nothing else changes."))
            var leaning = start
            leaning.island = .leaning
            cells.append(cell("hover.from-leaning.\(name)", "Hover", leaning, [(250, .over), (1500, .away)], tail: 1200,
                              Expect(state: "collapsed"),
                              "From leaning, resting on the island opens it in one growth; leaving closes it."))
        }
        cells.append(cell("hover.all-pages.music", "Hover", Start(music: .playing, pages: .all),
                          [(250, .near), (400, .over), (1700, .away)], tail: 1200, Expect(page: .player, state: "collapsed"),
                          "With every page on (nine tabs), the island still opens on the player and closes in one move each."))
        cells.append(cell("hover.all-pages.idle", "Hover", Start(pages: .all),
                          [(250, .near), (400, .over), (1700, .away)], tail: 1200, Expect(page: .pond, state: "collapsed"),
                          "With nothing going on and the pond on, the island opens on the pond."))
        return cells
    }

    // MARK: Pages: switching while open

    private static var pages: [Cell] {
        var cells: [Cell] = []
        let ring: [Page] = [.pond, .player, .calendar, .tasks, .system, .clipboard, .agents, .apps, .recorder, .pond]
        for (from, to) in zip(ring, ring.dropFirst()) {
            cells.append(cell("page.\(from)-\(to)", "Pages", Start(island: .open(from), music: .playing, pages: .all),
                              [(250, .click("tab.\(to)"))], tail: 1100, Expect(page: to, state: "expanded"),
                              "Height and page change together in one move; the selection pill travels; the island stays centred."))
        }
        for (from, to) in [(Page.calendar, Page.system), (.system, .clipboard), (.clipboard, .calendar)] {
            cells.append(cell("page.no-music.\(from)-\(to)", "Pages", Start(island: .open(from)),
                              [(250, .click("tab.\(to)"))], tail: 1100, Expect(page: to, state: "expanded"),
                              "Height and page change together in one move."))
        }
        cells.append(cell("page.player-calendar-player", "Pages", Start(island: .open(.player), music: .playing),
                          [(250, .click("tab.calendar")), (1000, .click("tab.player"))], tail: 1100,
                          Expect(page: .player, state: "expanded"),
                          "Away from the player and back: the artwork and bars leave and return without a second copy."))
        cells.append(cell("page.quick-three", "Pages", Start(island: .open(.player), music: .playing),
                          [(250, .click("tab.calendar")), (400, .click("tab.system")), (550, .click("tab.clipboard"))], tail: 1200,
                          Expect(page: .clipboard, state: "expanded"),
                          "Three picks 150 ms apart: the island retargets each time and ends on the last, with no jump."))
        cells.append(cell("page.clipboard-shelf", "Pages", Start(island: .open(.clipboard), music: .playing, pages: .all),
                          [(250, .clipboardMode(shelf: true)), (1100, .clipboardMode(shelf: false))], tail: 1100,
                          Expect(page: .clipboard, state: "expanded"),
                          "The Clipboard / Shelf switch changes the page's height in one move each way."))
        return cells
    }

    // MARK: Toasts: Copied, Keep Awake, levels

    private static var toasts: [Cell] {
        var cells: [Cell] = []
        let closed = closedStates.filter { !$0.name.contains("+") }
            + [("leaning", Start(island: .leaning)), ("leaning+music", Start(island: .leaning, music: .playing))]
        for kind in toastKinds {
            for (name, start) in closed {
                cells.append(cell("toast.\(kind).closed.\(name)", "Toasts", start, [(250, toastTrigger(kind))], tail: life(kind),
                                  Expect(state: "collapsed", toasts: [kind], still: true),
                                  "The closed island grows down by the band only; the toast slides up from the bottom edge and leaves the same way; what is beside the notch does not move."))
            }
            let everyPage: [Page] = [.pond, .player, .calendar, .tasks, .system, .clipboard, .agents, .apps, .recorder]
            for page in everyPage {
                cells.append(cell("toast.\(kind).open.\(page)", "Toasts", Start(island: .open(page), music: .playing, pages: .all),
                                  [(250, kind == "keepAwake" ? .click("ctl.keepAwake") : toastTrigger(kind))], tail: life(kind),
                                  Expect(page: page, state: "expanded", toasts: [kind],
                                         still: !(kind == "copied" && page == .clipboard)),
                                  "The open island grows by the band at its base; the toast slides up there and leaves the same way; the page and every control stay exactly where they were."))
            }
            for page in [Page.calendar, .system, .clipboard] {
                cells.append(cell("toast.\(kind).open.\(page).no-music", "Toasts", Start(island: .open(page)),
                                  [(250, toastTrigger(kind))], tail: life(kind),
                                  Expect(page: page, state: "expanded", toasts: [kind],
                                         still: !(kind == "copied" && page == .clipboard)),
                                  "Same as with music: the band at the base, the page untouched."))
            }
            cells.append(cell("toast.\(kind).teleprompter", "Toasts", Start(island: .teleprompter), [(250, toastTrigger(kind))],
                              tail: life(kind), Expect(state: "expanded", toasts: [kind], still: true),
                              "The teleprompter keeps its height and script; the band is added at the base and the handle follows the edge."))
        }
        for (name, start) in [("music", Start(island: .open(.clipboard), music: .playing)), ("no-music", Start(island: .open(.clipboard)))] {
            cells.append(cell("toast.copy-back.open.clipboard.\(name)", "Toasts", start, [(250, .click("clip.row.#1"))], tail: life("copied"),
                              Expect(page: .clipboard, state: "expanded", toasts: ["copied"]),
                              "Clicking a row copies it again: the same Copied toast in the base band, not a label swapped into the row."))
        }
        cells.append(cell("toast.keepAwake.open.player.recording", "Toasts",
                          Start(island: .open(.player), music: .playing, flags: [.recording]),
                          [(250, .click("ctl.keepAwake"))], tail: life("keepAwake"),
                          Expect(page: .player, state: "expanded", toasts: ["keepAwake"], still: true),
                          "With a recording's badge in the row: the band at the base, the row untouched."))
        cells.append(cell("toast.keepAwake.off.open.player", "Toasts", Start(island: .open(.player), music: .playing),
                          [(250, .click("ctl.keepAwake")), (3200, .click("ctl.keepAwake"))], tail: life("keepAwake"),
                          Expect(page: .player, state: "expanded", toasts: ["keepAwake"], still: true),
                          "On, then off three seconds later: each is its own toast in the band."))
        return cells
    }

    // MARK: Activities and notices

    private static var activities: [Cell] {
        var cells: [Cell] = []
        let kinds: [(name: String, shows: String, life: Double)] = [
            ("charging", "wings.charging", 4200), ("lowBattery", "notice.lowBattery", 7400),
            ("audioDevice", "notice.audioDevice", 5400), ("taskDue", "wings.taskDue", 4200),
            ("meetingReminder", "notice.meetingReminder", 3600), ("agentApproval", "notice.agentApproval", 3600),
            ("agentFinished", "wings.agentFinished", 4200), ("notification", "notice.notification", 7400),
            ("recorder", "notice.recorder", 7400),
        ]
        for kind in kinds {
            for (name, music) in [("idle", ContinuityCell.Music.off), ("music", .playing)] {
                var steps: [(Double, Trigger)] = [(250, .post(kind.name))]
                if kind.name == "meetingReminder" { steps.append((2200, .answerMeeting)) }
                if kind.name == "agentApproval" { steps.append((2200, .answerAgent)) }
                let tail = kind.life - (steps.last!.0 - 250)
                cells.append(cell("act.\(kind.name).closed.\(name)", "Notices",
                                  Start(music: music, needs: [.agents, .recorder]), steps, tail: tail,
                                  Expect(state: "collapsed", shows: [kind.shows]),
                                  kind.shows.hasPrefix("notice")
                                  ? "The notice grows out of the notch, shape first and words after, and goes back the same way, in one resize each."
                                  : "The wings grow out of the notch in one resize and fold back in one."))
            }
            cells.append(cell("act.\(kind.name).open.player", "Notices",
                              Start(island: .open(.player), music: .playing, needs: [.agents, .recorder]),
                              [(250, .post(kind.name))], tail: 1300,
                              Expect(page: .player, state: "expanded", quiet: true),
                              "Arriving while the island is open changes nothing on screen: no resize, no page change."))
        }
        cells.append(cell("act.lowBattery.closed.recording", "Notices", Start(flags: [.recording]),
                          [(250, .post("lowBattery"))], tail: 7400, Expect(state: "collapsed", shows: ["notice.lowBattery"]),
                          "The recording stays in the notch row while the notice hangs below it."))
        cells.append(cell("act.charging.closed.recording", "Notices", Start(flags: [.recording]),
                          [(250, .post("charging"))], tail: 4200, Expect(state: "collapsed", shows: ["wings.charging"]),
                          "The charging moment takes the wings and gives them back to the recording."))
        cells.append(cell("act.lowBattery.pointer-rests", "Notices", Start(),
                          [(250, .post("lowBattery")), (1400, .over), (2600, .away)], tail: 3200,
                          Expect(state: "collapsed", shows: ["notice.lowBattery"]),
                          "A notice stays put under the pointer instead of opening the island, then leaves after the pointer does."))
        cells.append(cell("act.notice-then-close.meetingReminder", "Notices", Start(island: .open(.player), music: .playing),
                          [(250, .post("meetingReminder")), (900, .away), (3000, .answerMeeting)], tail: 1500,
                          Expect(state: "collapsed", shows: ["notice.meetingReminder"]),
                          "A reminder that arrived while open shows as the island closes: one resize from open to the notice."))
        return cells
    }

    // MARK: Interruptions: a trigger arriving mid-animation

    private static var interruptions: [Cell] {
        var cells: [Cell] = []
        for kind in ["copied", "volume"] {
            for (name, music) in [("idle", ContinuityCell.Music.off), ("music", .playing)] {
                cells.append(cell("int.toast-during-expand.\(kind).\(name)", "Interruptions", Start(music: music),
                                  [(250, .over), (430, toastTrigger(kind))], tail: life(kind),
                                  Expect(state: "expanded", toasts: [kind]),
                                  "A toast arriving while the island is still growing joins at its base without a second bounce."))
            }
            cells.append(cell("int.toast-during-collapse.\(kind)", "Interruptions", Start(island: .open(.player), music: .playing),
                              [(250, .away), (480, toastTrigger(kind))], tail: life(kind),
                              Expect(state: "collapsed", toasts: [kind]),
                              "A toast arriving while the island is closing rides its base down to the closed island."))
        }
        cells.append(cell("int.two-toasts.same-kind", "Interruptions", Start(music: .playing),
                          [(250, .volume(0.5)), (450, .volume(0.6))], tail: life("volume"),
                          Expect(state: "collapsed", toasts: ["volume"]),
                          "Two of the same toast 200 ms apart: one band, updated in place; the island resizes once."))
        cells.append(cell("int.two-toasts.different.open", "Interruptions", Start(island: .open(.player), music: .playing),
                          [(250, .click("ctl.keepAwake")), (450, .copy)], tail: life("copied"),
                          Expect(page: .player, state: "expanded", toasts: ["copied"], glimpses: ["toast.keepAwake"]),
                          "Two different toasts 200 ms apart: the band stays, the second replaces the first inside it."))
        cells.append(cell("int.two-toasts.different.closed", "Interruptions", Start(),
                          [(250, .copy), (450, .volume(0.6))], tail: life("copied"),
                          Expect(state: "collapsed", toasts: ["volume"], glimpses: ["toast.copied"]),
                          "Two different toasts 200 ms apart on the closed island: the band stays down, no second bounce."))
        cells.append(cell("int.pointer-leaves-while-toast-slides", "Interruptions", Start(island: .open(.player), music: .playing),
                          [(250, .click("ctl.keepAwake")), (340, .away)], tail: life("keepAwake"),
                          Expect(page: .player, state: "collapsed", toasts: ["keepAwake"]),
                          "The pointer leaves while the toast slides in: the island closes and the toast stays at its base."))
        cells.append(cell("int.hover-while-toast-slides", "Interruptions", Start(music: .playing),
                          [(250, .copy), (320, .over)], tail: life("copied"),
                          Expect(page: .clipboard, state: "expanded", toasts: ["copied"]),
                          "Hovering as Copied slides in opens the island on the clipboard, with the toast still at the base."))
        cells.append(cell("int.page-switch-during-toast", "Interruptions", Start(island: .open(.player), music: .playing),
                          [(250, .click("ctl.keepAwake")), (480, .click("tab.calendar"))], tail: life("keepAwake"),
                          Expect(page: .calendar, state: "expanded", toasts: ["keepAwake"]),
                          "Picking a page while a toast shows: the page changes in one move and the band stays at the new base."))
        cells.append(cell("int.toast-during-page-switch", "Interruptions", Start(island: .open(.player), music: .playing),
                          [(250, .click("tab.calendar")), (330, .volume(0.6))], tail: life("volume"),
                          Expect(page: .calendar, state: "expanded", toasts: ["volume"]),
                          "A toast arriving mid page switch joins the base; the page the user picked stays."))
        cells.append(cell("int.toast-during-notice", "Interruptions", Start(flags: [.lowBattery]),
                          [(250, .volume(0.6))], tail: life("volume"),
                          Expect(state: "collapsed", toasts: ["volume"], shows: ["notice.lowBattery"]),
                          "A level changed while a notice shows: the band is added under the notice, which does not move."))
        cells.append(cell("int.notice-during-toast", "Interruptions", Start(),
                          [(250, .copy), (700, .post("charging"))], tail: 4600,
                          Expect(state: "collapsed", toasts: ["copied"], shows: ["wings.charging"]),
                          "A charger connected while Copied shows: the wings grow out above the band; each leaves in its own time."))
        cells.append(cell("int.hover-during-toast-exit", "Interruptions", Start(music: .playing),
                          [(250, .volume(0.6)), (1850, .over)], tail: 1500,
                          Expect(page: .player, state: "expanded", toasts: ["volume"]),
                          "Hovering as a toast leaves: the island opens in one growth while the band finishes leaving."))
        cells.append(cell("int.out-and-back-in", "Interruptions", Start(island: .open(.player), music: .playing),
                          [(250, .away), (330, .inside)], tail: 900, Expect(page: .player, state: "expanded", quiet: true),
                          "Leaving and coming back within 150 ms: the island never starts to close."))
        cells.append(cell("int.reopen-mid-close", "Interruptions", Start(island: .open(.player), music: .playing),
                          [(250, .away), (560, .over)], tail: 1300, Expect(page: .player, state: "expanded"),
                          "Coming back while the island is closing: it turns round from where it is, with no jump."))
        cells.append(cell("int.close-mid-open", "Interruptions", Start(music: .playing),
                          [(250, .over), (500, .away)], tail: 1300, Expect(state: "collapsed"),
                          "Leaving while the island is opening: it turns round from where it is."))
        cells.append(cell("int.music-starts-during-toast", "Interruptions", Start(),
                          [(250, .copy), (700, .music(.playing))], tail: life("copied"),
                          Expect(state: "collapsed", toasts: ["copied"]),
                          "Music starting while a toast shows: the wings grow out, the band stays where it is."))
        cells.append(cell("int.lean-during-toast", "Interruptions", Start(),
                          [(250, .copy), (800, .near), (1500, .away)], tail: 3200,
                          Expect(state: "collapsed", toasts: ["copied"]),
                          "The pointer coming near while a toast shows: the island leans, the toast stays in its band."))
        cells.append(cell("int.expand-during-notice-exit", "Interruptions", Start(music: .playing),
                          [(250, .post("taskDue")), (3300, .over)], tail: 1500, Expect(page: .player, state: "expanded"),
                          "Hovering as an activity's wings fold back: one growth into the open island."))
        return cells
    }

    // MARK: Media keys

    private static var keys: [Cell] {
        func held(_ make: (Float) -> Trigger) -> [(Double, Trigger)] {
            (0..<7).map { (250 + Double($0) * 70, make(0.4 + Float($0) * 0.06)) }
        }
        return [
            cell("keys.volume-held.closed.idle", "Media keys", Start(), held { .volume($0) }, tail: life("volume"),
                 Expect(state: "collapsed", toasts: ["volume"], still: true),
                 "A held volume key: one band, the level following the key; the island resizes once in and once out."),
            cell("keys.volume-held.closed.music", "Media keys", Start(music: .playing), held { .volume($0) }, tail: life("volume"),
                 Expect(state: "collapsed", toasts: ["volume"], still: true),
                 "With music beside the notch: the band below it; the artwork and bars do not move or swap."),
            cell("keys.volume-held.open.player", "Media keys", Start(island: .open(.player), music: .playing), held { .volume($0) },
                 tail: life("volume"), Expect(page: .player, state: "expanded", toasts: ["volume"], still: true),
                 "Open on the player: the level is in the base band; the scrubber stays where it is."),
            cell("keys.volume-held.open.calendar", "Media keys", Start(island: .open(.calendar), music: .playing), held { .volume($0) },
                 tail: life("volume"), Expect(page: .calendar, state: "expanded", toasts: ["volume"], still: true),
                 "Open on another page: the same band at the base."),
            cell("keys.mute.closed.music", "Media keys", Start(music: .playing), [(250, .volume(0.5)), (700, .mute)],
                 tail: life("volume"), Expect(state: "collapsed", toasts: ["volume"], still: true),
                 "Mute after a level: the same toast dims in place."),
            cell("keys.brightness-held.closed.idle", "Media keys", Start(), held { .brightness($0) }, tail: life("brightness"),
                 Expect(state: "collapsed", toasts: ["brightness"], still: true),
                 "A held brightness key behaves like volume: one band, one resize each way."),
            cell("keys.volume-then-brightness.closed.music", "Media keys", Start(music: .playing),
                 [(250, .volume(0.5)), (650, .brightness(0.7))], tail: life("brightness"),
                 Expect(state: "collapsed", toasts: ["brightness"], glimpses: ["toast.volume"], still: true),
                 "Volume then brightness: the band stays, the second level replaces the first inside it."),
        ]
    }

    // MARK: Teleprompter

    private static var teleprompter: [Cell] {
        func drag(to distance: CGFloat, from start: Double = 250, over duration: Double = 360) -> [(Double, Trigger)] {
            (1...12).map { (start + duration * Double($0) / 12, Trigger.teleDrag(distance * CGFloat($0) / 12)) }
        }
        return [
            cell("tele.start.from-open", "Teleprompter", Start(island: .open(.calendar)), [(250, .teleStart)], tail: 1300,
                 Expect(state: "expanded"), "The open island widens and the script takes the page's place in one move."),
            cell("tele.start.from-closed", "Teleprompter", Start(), [(250, .teleStart)], tail: 1300,
                 Expect(state: "expanded"), "From closed: one growth into the teleprompter."),
            cell("tele.stop.pointer-inside", "Teleprompter", Start(island: .teleprompter), [(250, .teleStop)], tail: 1300,
                 Expect(state: "expanded"), "Stopping with the pointer inside: back to the pages in one move."),
            cell("tele.stop.pointer-away", "Teleprompter", Start(island: .teleprompter), [(240, .away), (250, .teleStop)], tail: 1300,
                 Expect(state: "collapsed"), "Stopping with the pointer away: the island closes in one move."),
            cell("tele.drag.down", "Teleprompter", Start(island: .teleprompter), drag(to: 90) + [(640, .teleRelease(120))], tail: 1200,
                 Expect(state: "expanded"), "The height follows the handle directly, then settles where its momentum carries it."),
            cell("tele.drag.up", "Teleprompter", Start(island: .teleprompter), drag(to: -40) + [(640, .teleRelease(-48))], tail: 1200,
                 Expect(state: "expanded"), "Pushed up: follows directly, settles once."),
            cell("tele.drag.past-max", "Teleprompter", Start(island: .teleprompter), drag(to: 330) + [(640, .teleRelease(360))], tail: 1200,
                 Expect(state: "expanded"), "Past the limit it resists, then settles back to the limit in one move."),
        ]
    }

    // MARK: Display change

    private static var display: [Cell] {
        let other = CGSize(width: 200, height: 24)
        return [
            cell("display.closed.idle", "Display", Start(), [(250, .display(other))], Expect(state: "collapsed"),
                 "Another display's notch: the island re-seats on it at once, centred, radii unchanged."),
            cell("display.closed.music", "Display", Start(music: .playing), [(250, .display(other))], Expect(state: "collapsed"),
                 "With music: the wings re-seat with the island; no second copy of the artwork."),
            cell("display.open.player", "Display", Start(island: .open(.player), music: .playing), [(250, .display(other))],
                 Expect(page: .player, state: "expanded"), "Open: the island re-seats, the page stays."),
        ]
    }

    // MARK: Reduce Motion

    private static var reduceMotion: [Cell] {
        func rm(_ start: Start) -> Start {
            var start = start
            start.reduceMotion = true
            return start
        }
        return [
            cell("rm.hover.idle", "Reduce Motion", rm(Start()), [(250, .over), (1400, .away)], tail: 1100,
                 Expect(page: .calendar, state: "collapsed"), "Opens and closes with fades only: nothing travels."),
            cell("rm.hover.music", "Reduce Motion", rm(Start(music: .playing)), [(250, .over), (1400, .away)], tail: 1100,
                 Expect(page: .player, state: "collapsed"), "With music: the artwork changes place without travelling."),
            cell("rm.lean", "Reduce Motion", rm(Start()), [(250, .near), (1000, .away)], Expect(state: "collapsed"),
                 "The lean happens without a spring."),
            cell("rm.page.player-calendar", "Reduce Motion", rm(Start(island: .open(.player), music: .playing)),
                 [(250, .click("tab.calendar"))], tail: 1100, Expect(page: .calendar, state: "expanded"),
                 "The page changes with a fade; the height changes at once."),
            cell("rm.toast.keepAwake.open.player", "Reduce Motion", rm(Start(island: .open(.player), music: .playing)),
                 [(250, .click("ctl.keepAwake"))], tail: life("keepAwake"),
                 Expect(page: .player, state: "expanded", toasts: ["keepAwake"]), "The toast fades in at the base; no slide."),
            cell("rm.toast.copied.closed.idle", "Reduce Motion", rm(Start()), [(250, .copy)], tail: life("copied"),
                 Expect(state: "collapsed", toasts: ["copied"]), "Closed: the band appears at once and the toast fades in it."),
            cell("rm.toast.volume.closed.music", "Reduce Motion", rm(Start(music: .playing)), [(250, .volume(0.6))],
                 tail: life("volume"), Expect(state: "collapsed", toasts: ["volume"]), "With music: the same, music untouched."),
            cell("rm.act.lowBattery.closed", "Reduce Motion", rm(Start()), [(250, .post("lowBattery"))], tail: 7400,
                 Expect(state: "collapsed", shows: ["notice.lowBattery"]), "The notice fades in and out; nothing travels."),
            cell("rm.act.charging.closed", "Reduce Motion", rm(Start()), [(250, .post("charging"))], tail: 4200,
                 Expect(state: "collapsed", shows: ["wings.charging"]), "The charging moment appears without motion."),
            cell("rm.tele.start", "Reduce Motion", rm(Start(island: .open(.calendar))), [(250, .teleStart)], tail: 1200,
                 Expect(state: "expanded"), "The teleprompter takes the island with a fade."),
        ]
    }

    // MARK: Arrivals: something starting or stopping beside the notch

    private static var arrivals: [Cell] {
        var cells: [Cell] = [
            cell("arrive.music.start", "Arrivals", Start(), [(250, .music(.playing))], Expect(state: "collapsed"),
                 "The wings grow out of the notch in one resize; the artwork and bars fade in, in place."),
            cell("arrive.music.pause-hide", "Arrivals", Start(music: .playing), [(250, .music(.paused))], tail: 4300,
                 Expect(state: "collapsed"), "Paused: the wings stay 3 s, then fold back in one resize."),
            cell("arrive.music.stop", "Arrivals", Start(music: .playing), [(250, .music(.off))], Expect(state: "collapsed"),
                 "The track ends: the wings fold back in one resize."),
            cell("arrive.music.start.open.calendar", "Arrivals", Start(island: .open(.calendar)), [(250, .music(.playing))],
                 tail: 1100, Expect(page: .calendar, state: "expanded"),
                 "Music starting while open on the calendar adds the player's tab; the page does not change."),
            cell("arrive.music.stop.open.player", "Arrivals", Start(island: .open(.player), music: .playing), [(250, .music(.off))],
                 tail: 1100, Expect(state: "expanded"),
                 "The track ending while open on the player: the page falls back to the first one in a single move."),
        ]
        let things: [(String, Trigger, Trigger, Set<ContinuityCell.Need>)] = [
            ("recording", .recording(true), .recording(false), [.recorder]),
            ("agent", .agent(true), .agent(false), [.agents]),
            ("meeting", .meeting(8), .meeting(nil), []),
            ("koi", .koi(true), .koi(false), []),
        ]
        for (name, on, off, needs) in things {
            for (state, music) in [("idle", ContinuityCell.Music.off), ("music", .playing)] {
                cells.append(cell("arrive.\(name).\(state)", "Arrivals", Start(music: music, needs: needs),
                                  [(250, on), (1700, off)], tail: 1200, Expect(state: "collapsed"),
                                  "Its wings grow out in one resize and fold back in one; music beside the notch fades out and back, never two copies."))
            }
        }
        return cells
    }

    // MARK: Relevance: which page the island opens on

    private static var relevance: [Cell] {
        [
            cell("rel.copy-then-hover", "Relevance", Start(music: .playing), [(250, .copy), (3600, .over)], tail: 1300,
                 Expect(page: .clipboard, state: "expanded", toasts: ["copied"]),
                 "A copy a few seconds ago: the island opens on the clipboard, though music is playing."),
            cell("rel.copy-59s", "Relevance", Start(music: .playing), [(100, .copied(59)), (250, .over)], tail: 1300,
                 Expect(page: .clipboard, state: "expanded"), "A copy 59 s ago still opens the clipboard."),
            cell("rel.copy-61s", "Relevance", Start(music: .playing), [(100, .copied(61)), (250, .over)], tail: 1300,
                 Expect(page: .player, state: "expanded"), "A copy 61 s ago no longer does: music opens the player."),
            cell("rel.meeting-9min", "Relevance", Start(music: .playing), [(100, .meeting(9)), (700, .over)], tail: 1300,
                 Expect(page: .calendar, state: "expanded"), "A call 9 min away opens the calendar, over music."),
            cell("rel.meeting-11min", "Relevance", Start(music: .playing), [(100, .meeting(11)), (700, .over)], tail: 1300,
                 Expect(page: .player, state: "expanded"), "A call 11 min away does not: music opens the player."),
            cell("rel.copy-over-meeting", "Relevance", Start(music: .playing, flags: [.meeting]), [(100, .copied(10)), (250, .over)],
                 tail: 1300, Expect(page: .clipboard, state: "expanded"), "A fresh copy outranks a call about to start."),
            cell("rel.pick-holds", "Relevance", Start(island: .open(.player), music: .playing),
                 [(250, .click("tab.system")), (900, .copy), (1500, .meeting(8)), (2300, .music(.paused))], tail: 3200,
                 Expect(page: .system, state: "expanded", toasts: ["copied"]),
                 "While the island is open, a copy, a call coming up and music pausing never change the page the user picked."),
        ]
    }
}
#endif
