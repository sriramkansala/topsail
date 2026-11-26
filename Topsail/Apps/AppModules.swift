import AppKit
import Combine

/// What the Apps page shows of other apps, while they're open and the page is on screen: the front
/// Terminal tab's last lines, Chrome's tabs, and a YouTube video playing in Chrome. Asked over
/// AppleScript (macOS asks the user once per app), so the direct download only. Private Chrome
/// windows are never read. Scripts are fixed text with at most numbers filled in.
@MainActor
final class AppModules: ObservableObject {
    struct Terminal: Equatable {
        let busy: Bool
        let lines: [String]
    }

    struct Tab: Equatable, Identifiable {
        let window: Int
        let index: Int
        let number: Int
        let title: String
        let url: URL?
        let active: Bool
        var id: Int { number }

        var isYouTubeVideo: Bool {
            guard let host = url?.host()?.lowercased(), url?.scheme == "https" else { return false }
            return (host == "youtube.com" || host == "www.youtube.com") && url?.path() == "/watch"
        }
    }

    @Published private(set) var terminal: Terminal?
    @Published private(set) var tabs: [Tab] = []
    /// Something an app refused: which, and how to allow it.
    @Published private(set) var problem: String?
    @Published private(set) var terminalOpen = false
    @Published private(set) var chromeOpen = false
    /// The apps have answered since the page came on screen.
    @Published private(set) var loaded = false

    var showsTerminal = true
    var showsChrome = true
    var showsYouTube = true

    private static let terminalID = "com.apple.Terminal"
    private static let chromeID = "com.google.Chrome"
    static let visibleLines = 4
    static let visibleTabs = 4

    private var timer: Timer?
    private var awaiting = 0

    /// The front window's active tab, then the newest others (Chrome numbers tabs as they open).
    var listedTabs: [Tab] {
        guard showsChrome else { return [] }
        let front = tabs.filter { $0.window == 1 }
        return Array((front.filter(\.active) + front.filter { !$0.active }.sorted { $0.number > $1.number })
            .prefix(Self.visibleTabs))
    }

    var video: Tab? { showsYouTube ? tabs.first(where: \.isYouTubeVideo) : nil }

    var isEmpty: Bool { terminal == nil && listedTabs.isEmpty && video == nil }

    private var asksTerminal: Bool { showsTerminal && terminalOpen }
    private var asksChrome: Bool { (showsChrome || showsYouTube) && chromeOpen }

    /// Whether the page needs its full height: something to show, or an open app yet to answer.
    /// Otherwise it's a one-line message.
    var needsRoom: Bool {
        !isEmpty || problem != nil || (!loaded && (asksTerminal || asksChrome))
    }

    /// Which of the apps are open, before the island sizes the page.
    func noteOpenApps() {
        #if DEBUG
        if Continuity.isActive { return }  // continuity tests: fixture data only
        #endif
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let terminal = running.contains(Self.terminalID), chrome = running.contains(Self.chromeID)
        if terminal != terminalOpen { terminalOpen = terminal }
        if chrome != chromeOpen { chromeOpen = chrome }
    }

    /// The page came on (or went off) screen.
    func setVisible(_ visible: Bool) {
        #if DEBUG
        if Continuity.isActive { return }  // continuity tests: fixture data only
        #endif
        timer?.invalidate()
        timer = nil
        awaiting = 0
        loaded = false
        guard visible else {
            terminal = nil
            tabs = []
            problem = nil
            return
        }
        refresh()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func refresh() {
        #if DIRECT
        // Only apps already open: asking one that isn't would launch it.
        noteOpenApps()
        if asksTerminal {
            awaiting += 1
            AppleScriptRunner.run(Self.terminalScript) { [weak self] outcome in
                self?.report(outcome, app: "Terminal")
                guard self?.timer != nil else { return }
                let value = outcome.descriptor?.stringValue.flatMap(Self.parseTerminal)
                if self?.terminal != value { self?.terminal = value }
                self?.answered()
            }
        } else if terminal != nil {
            terminal = nil
        }
        if asksChrome {
            awaiting += 1
            AppleScriptRunner.run(Self.chromeScript) { [weak self] outcome in
                self?.report(outcome, app: "Chrome")
                guard self?.timer != nil else { return }
                let value = Self.parseTabs(Self.rows(outcome.descriptor))
                if self?.tabs != value { self?.tabs = value }
                self?.answered()
            }
        } else if !tabs.isEmpty {
            tabs = []
        }
        #endif
    }

    private func answered() {
        awaiting = max(0, awaiting - 1)
        if awaiting == 0, !loaded { loaded = true }
    }

    func show(_ tab: Tab) {
        AppleScriptRunner.run("""
            tell application id "\(Self.chromeID)"
                set active tab index of window \(tab.window) to \(tab.index)
                set index of window \(tab.window) to 1
                activate
            end tell
            """)
    }

    func copyLink(_ tab: Tab) {
        guard let url = tab.url else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
    }

    /// Plays or pauses the video. Chrome only runs a script in a page if the user allowed it
    /// (View > Developer), and says so otherwise. The tab is checked again first: it may have moved.
    func togglePlayback(_ tab: Tab) {
        AppleScriptRunner.run("""
            tell application id "\(Self.chromeID)"
                set t to tab \(tab.index) of window \(tab.window)
                if URL of t starts with "https://www.youtube.com/watch" or URL of t starts with "https://youtube.com/watch" then
                    execute t javascript "(function(){var v=document.querySelector('video');if(v){if(v.paused){v.play()}else{v.pause()}}})()"
                end if
            end tell
            """) { [weak self] outcome in
            if outcome.errorNumber != nil, outcome.errorNumber != -1743 {
                self?.problem = String(localized: "To play and pause from here, turn on View › Developer › Allow JavaScript from Apple Events in Chrome. It lets any app you allow to control Chrome run scripts in its pages.")
            } else {
                self?.report(outcome, app: "Chrome")
            }
        }
    }

    private func report(_ outcome: AppleScriptRunner.Outcome, app: String) {
        if outcome.errorNumber == -1743 {
            problem = String(localized: "Allow Topsail to control \(app) under Privacy & Security › Automation.")
        }
    }

    // MARK: Scripts and their answers

    static let terminalScript = """
        tell application id "com.apple.Terminal"
            if (count of windows) is 0 then return ""
            return ((busy of selected tab of front window) as text) & linefeed & (contents of selected tab of front window)
        end tell
        """

    static let chromeScript = """
        tell application id "com.google.Chrome"
            set found to {}
            repeat with w from 1 to (count of windows)
                if mode of window w is not "incognito" then
                    set a to active tab index of window w
                    repeat with i from 1 to (count of tabs of window w)
                        set t to tab i of window w
                        set end of found to {w as text, i as text, (id of t) as text, (i = a) as text, title of t, URL of t}
                    end repeat
                end if
            end repeat
            return found
        end tell
        """

    /// "true\n<contents>": whether a command is running, and the last lines with anything on them.
    static func parseTerminal(_ text: String) -> Terminal? {
        guard let newline = text.firstIndex(of: "\n") else { return nil }
        let lines = text[text.index(after: newline)...]
            .split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return Terminal(busy: text[..<newline] == "true", lines: Array(lines.suffix(visibleLines)))
    }

    private static func rows(_ descriptor: NSAppleEventDescriptor?) -> [[String]] {
        guard let descriptor, descriptor.numberOfItems > 0 else { return [] }
        return (1...descriptor.numberOfItems).compactMap { descriptor.atIndex($0) }.map { row in
            row.numberOfItems == 0 ? [] : (1...row.numberOfItems).map { row.atIndex($0)?.stringValue ?? "" }
        }
    }

    static func parseTabs(_ rows: [[String]]) -> [Tab] {
        rows.compactMap { row in
            guard row.count == 6, let window = Int(row[0]), let index = Int(row[1]), let number = Int(row[2]),
                  window > 0, index > 0 else { return nil }
            return Tab(window: window, index: index, number: number, title: row[4], url: URL(string: row[5]),
                       active: row[3] == "true")
        }
    }
}
