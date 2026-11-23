import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchViewModel: ObservableObject {
    enum IslandState {
        case collapsed
        case expanded
    }

    /// The calendar tab's two halves.
    enum CalendarMode {
        case events
        case reminders
    }

    /// The clipboard tab's two halves.
    enum ClipboardMode {
        case clipboard
        case shelf
    }

    /// What the expanded island shows; only one page at a time.
    enum ExpandedPage {
        case player
        case calendar
        case tasks
        case system
        case clipboard
        case agents
    }

    @Published private(set) var state: IslandState = .collapsed
    @Published var notchSize: CGSize = .zero
    @Published var notchRect: CGRect = .zero
    @Published private(set) var showsMusicActivity = false
    /// An AI agent is working (and the Agents feature is on): its glyph beside the notch.
    @Published private(set) var showsAgentActivity = false
    /// A meeting with a join link starts soon (or just started) and reminders are on.
    @Published private(set) var showsMeetingActivity = false
    /// The tasks page shows more than two issues after "View more"; reset when the island closes.
    @Published private(set) var tasksExpanded = false
    /// A voice note is in progress: the island holds it, pinned open, sized to its content.
    @Published private(set) var voiceActive = false
    /// The teleprompter is running: the island holds it, pinned open.
    @Published private(set) var teleprompterActive = false
    /// Natural height of the voice note's content, reported by `VoiceIslandView`.
    @Published private(set) var voiceHeight: CGFloat = 160
    @Published private(set) var page: ExpandedPage = .player
    @Published private(set) var clipboardMode: ClipboardMode = .clipboard
    @Published private(set) var calendarMode: CalendarMode = .events
    /// Files are being dragged over the open island: the shelf lights up to take them.
    @Published private(set) var shelfTargeted = false
    /// Height of the page below the notch row; the expanded island hugs it.
    @Published private(set) var expandedContentHeight: CGFloat = IslandLayout.messageHeight

    let nowPlaying: NowPlayingService
    let activities: ActivityCenter
    let calendar: CalendarService
    let linear: LinearService
    let voice: VoiceNoteController
    let system: SystemMonitor
    let clipboard: ClipboardHistory
    let features: FeatureServices
    let settings: AppSettings
    let compactWing: CGFloat = 42

    private let collapsedTopRadius: CGFloat = 6
    private let collapsedBottomRadius: CGFloat = 14

    var onStateChange: ((IslandState) -> Void)?
    var onOpenSettings: (() -> Void)?
    /// The low-battery notice was clicked.
    var onRequestLowPowerMode: (() -> Void)?
    /// A voice note opened the island: the window takes keyboard focus for ⏎ / Esc and renaming.
    var onVoicePresent: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var pendingExpand: DispatchWorkItem?
    private var pendingCollapse: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    private var hideActivityWork: DispatchWorkItem?

    init(nowPlaying: NowPlayingService, activities: ActivityCenter, calendar: CalendarService,
         linear: LinearService, voice: VoiceNoteController, system: SystemMonitor, clipboard: ClipboardHistory,
         features: FeatureServices, settings: AppSettings) {
        self.nowPlaying = nowPlaying
        self.activities = activities
        self.calendar = calendar
        self.linear = linear
        self.voice = voice
        self.system = system
        self.clipboard = clipboard
        self.features = features
        self.settings = settings

        // Only whether a note is running matters here; the note's own updates (waveform levels,
        // transcript) are observed by its view directly, so the island doesn't redraw for them.
        voice.$phase
            .map { $0 != .idle }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in self?.setVoiceActive(active) }
            .store(in: &cancellables)

        // An agent working shows beside the notch: grows in, shrinks out.
        Publishers.CombineLatest(features.agents.$sessions.map { $0.contains(where: \.isWorking) },
                                 settings.publisher(for: .agents))
            .map { $0 && $1 }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shows in
                guard let self, shows != self.showsAgentActivity else { return }
                Motion.perform(shows ? Motion.islandGrow : Motion.islandShrink) {
                    self.showsAgentActivity = shows
                }
            }
            .store(in: &cancellables)

        features.teleprompter.$isActive
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] active in self?.setTeleprompterActive(active) }
            .store(in: &cancellables)

        // Views read settings (e.g. whether to show the calendar) through the model.
        settings.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // The expanded height follows the page and what it shows.
        let changes: [AnyPublisher<Void, Never>] = [
            $page.map { _ in () }.eraseToAnyPublisher(),
            $clipboardMode.map { _ in () }.eraseToAnyPublisher(),
            $calendarMode.map { _ in () }.eraseToAnyPublisher(),
            features.reminders.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            features.agents.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            nowPlaying.$track.map { $0 != nil }.removeDuplicates().map { _ in () }.eraseToAnyPublisher(),
            calendar.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            linear.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            settings.$showCalendar.map { _ in () }.eraseToAnyPublisher(),
            settings.$showClipboard.map { _ in () }.eraseToAnyPublisher(),
            settings.$features.map { _ in () }.eraseToAnyPublisher(),
            clipboard.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            features.shelf.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(changes)
        .receive(on: DispatchQueue.main)
        .sink { [weak self] in
            self?.objectWillChange.send()
            self?.updateContentHeight(animated: true)
        }
        .store(in: &cancellables)

        // "Meeting soon" beside the notch: grows in, shrinks out, like the other activities.
        Publishers.CombineLatest(calendar.$imminentMeeting.map { $0 != nil }, settings.$showMeetingReminders)
            .map { $0 && $1 }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] shows in
                guard let self, shows != self.showsMeetingActivity else { return }
                Motion.perform(shows ? Motion.islandGrow : Motion.islandShrink) {
                    self.showsMeetingActivity = shows
                }
            }
            .store(in: &cancellables)

        // `islandSize` reads `activities.current`, so republish when it changes.
        activities.$current
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        let trackPublisher = nowPlaying.$track.map { $0 != nil }
        let playingPublisher = nowPlaying.$isPlaying

        Publishers.CombineLatest3(trackPublisher, playingPublisher, settings.$showMusicActivity)
            .removeDuplicates { $0 == $1 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hasTrack, isPlaying, enabled in
                guard let self else { return }

                if hasTrack && isPlaying && enabled {
                    // Playing with a track: show immediately.
                    self.cancelPendingHide()
                    if !self.showsMusicActivity {
                        Motion.perform(Motion.islandGrow) {
                            self.showsMusicActivity = true
                        }
                    }
                } else if hasTrack && enabled {
                    // Paused: keep showing for 3 s before hiding.
                    self.scheduleHide(after: 3)
                } else {
                    // No track, or the music activity is turned off in settings.
                    self.cancelPendingHide()
                    if self.showsMusicActivity {
                        Motion.perform(Motion.islandShrink) {
                            self.showsMusicActivity = false
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }

    var islandSize: CGSize {
        switch state {
        case .collapsed:
            // A transient activity (charging, device connected) takes priority, then an
            // imminent meeting, then music.
            if activities.current != nil {
                return CGSize(width: notchSize.width + 2 * activityWingWidth,
                              height: notchSize.height + activities.meterHeight)
            }
            if showsMeetingActivity {
                return CGSize(width: notchSize.width + 2 * IslandLayout.activityWing, height: notchSize.height)
            }
            if showsAgentActivity {
                return CGSize(width: notchSize.width + 2 * compactWing, height: notchSize.height)
            }
            if showsMusicActivity {
                return CGSize(width: notchSize.width + 2 * compactWing, height: notchSize.height)
            }
            return notchSize
        case .expanded:
            return expandedSize
        }
    }

    /// Each wing of the activity on screen. "Copied to clipboard" grows the notch downward only,
    /// keeping the narrow music wings if music is showing; every other activity takes the open
    /// island's width.
    var activityWingWidth: CGFloat {
        if activities.current?.kind == .copied { return showsMusicActivity ? compactWing : 0 }
        return activities.wingWidth
    }

    // MARK: - Voice notes

    /// The voice note asked to be shown: open the island (it stays pinned while the note runs).
    func presentVoice() {
        if state == .collapsed { expand() }
        onVoicePresent?()
    }

    func setVoiceHeight(_ height: CGFloat) {
        let height = height.rounded()
        guard height > 0, abs(height - voiceHeight) >= 1 else { return }
        if state == .expanded && voiceActive {
            Motion.perform(Motion.gentle) { voiceHeight = height }
        } else {
            voiceHeight = height
        }
    }

    private func setVoiceActive(_ active: Bool) {
        guard active != voiceActive else { return }
        Motion.perform(Motion.gentle) { voiceActive = active }
        // When the note ends, let the island go unless the pointer is still over it.
        if !active, state == .expanded, !expandedActiveZone().contains(NSEvent.mouseLocation) {
            collapse()
        }
    }

    // MARK: - Teleprompter

    /// Starts the script from Settings (the notch row's button, the menu bar, Settings).
    func startTeleprompter() {
        guard settings.isEnabled(.teleprompter) else { return }
        features.teleprompter.start(script: settings.teleprompterScript, speed: settings.teleprompterSpeed)
    }

    private func setTeleprompterActive(_ active: Bool) {
        guard active != teleprompterActive else { return }
        Motion.perform(Motion.gentle) { teleprompterActive = active }
        if active {
            if state == .collapsed { expand() }
            onVoicePresent?()  // takes the keyboard, for Space, arrows and Esc
        } else if state == .expanded, !expandedActiveZone().contains(NSEvent.mouseLocation) {
            collapse()
        }
    }

    var topRadius: CGFloat {
        switch state {
        case .collapsed: return collapsedTopRadius
        case .expanded: return IslandLayout.expandedTopRadius
        }
    }

    var bottomRadius: CGFloat {
        switch state {
        case .collapsed: return collapsedBottomRadius
        case .expanded: return IslandLayout.expandedBottomRadius
        }
    }

    func update(notchRect: CGRect) {
        self.notchRect = notchRect
        self.notchSize = CGSize(width: notchRect.width, height: notchRect.height)
    }

    func startTracking() {
        guard globalMonitor == nil, localMonitor == nil else { return }

        // Mouse-down only marks where a drag would start (for the shelf).
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in
            let isDown = event.type == .leftMouseDown
            MainActor.assumeIsolated {
                self?.handle(isDown: isDown)
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            let isDown = event.type == .leftMouseDown
            MainActor.assumeIsolated {
                self?.handle(isDown: isDown)
            }
            return event
        }
    }

    func stopTracking() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        pendingExpand?.cancel()
        pendingExpand = nil
        pendingCollapse?.cancel()
        pendingCollapse = nil
    }

    private func handle(isDown: Bool) {
        if isDown {
            dragChangeCount = NSPasteboard(name: .drag).changeCount
        } else {
            handleMouse(at: NSEvent.mouseLocation)
        }
    }

    private func handleMouse(at location: CGPoint) {
        switch state {
        case .collapsed:
            let hotZone = collapsedHotZone()
            // The low-battery notice stays put under the pointer, to be read or clicked, instead
            // of giving way to the open island.
            if activities.current?.kind.isNotice == true {
                cancelPendingExpand()
                activities.pointerMoved(inside: hotZone.contains(location))
                return
            }
            if hotZone.contains(location) {
                scheduleExpand(after: 0.06)
            } else {
                cancelPendingExpand()
            }
        case .expanded:
            // A voice note or the teleprompter keeps the island open wherever the pointer goes.
            guard !voiceActive, !teleprompterActive else {
                cancelPendingCollapse()
                return
            }
            let activeZone = expandedActiveZone()
            if activeZone.contains(location) {
                cancelPendingCollapse()
            } else {
                scheduleCollapse(after: 0.25)
            }
        }
    }

    private func collapsedHotZone() -> CGRect {
        let width = islandSize.width
        var zone = CGRect(
            x: notchRect.midX - width / 2,
            y: notchRect.maxY - islandSize.height,
            width: width,
            height: islandSize.height
        )
        zone = zone.insetBy(dx: -10, dy: -6)
        if zone.maxY < notchRect.maxY {
            zone.size.height += (notchRect.maxY - zone.maxY)
        }
        return zone
    }

    private func expandedActiveZone() -> CGRect {
        let rect = CGRect(
            x: notchRect.midX - expandedSize.width / 2,
            y: notchRect.maxY - expandedSize.height,
            width: expandedSize.width,
            height: expandedSize.height
        )
        return rect.insetBy(dx: -14, dy: -14)
    }

    private func scheduleExpand(after delay: TimeInterval) {
        if pendingExpand != nil { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.state == .collapsed else { return }
                self.pendingExpand = nil
                self.expand()
            }
        }
        pendingExpand = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func scheduleCollapse(after delay: TimeInterval) {
        if pendingCollapse != nil { return }
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.state == .expanded else { return }
                self.pendingCollapse = nil
                self.collapse()
            }
        }
        pendingCollapse = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelPendingExpand() {
        pendingExpand?.cancel()
        pendingExpand = nil
    }

    private func cancelPendingCollapse() {
        pendingCollapse?.cancel()
        pendingCollapse = nil
    }

    private func scheduleHide(after delay: TimeInterval) {
        cancelPendingHide()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                // Only hide if still paused (no track or not playing).
                guard !self.nowPlaying.isPlaying else { return }
                self.hideActivityWork = nil
                Motion.perform(Motion.islandShrink) {
                    self.showsMusicActivity = false
                }
            }
        }
        hideActivityWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func cancelPendingHide() {
        hideActivityWork?.cancel()
        hideActivityWork = nil
    }

    var expandedSize: CGSize {
        if voiceActive {
            return CGSize(width: IslandLayout.voiceWidth, height: notchSize.height + voiceHeight)
        }
        if teleprompterActive {
            return CGSize(width: max(IslandLayout.teleprompterWidth, notchSize.width + 2 * IslandLayout.minimumExpandedWing),
                          height: notchSize.height + IslandLayout.teleprompterHeight)
        }
        let wing = IslandLayout.expandedWing(tabs: showsPageTabs ? availablePages.count : 0)
        return CGSize(width: max(IslandLayout.expandedWidth, notchSize.width + 2 * wing),
               height: notchSize.height + IslandLayout.contentTopPadding + expandedContentHeight
                   + IslandLayout.contentBottomPadding)
    }

    /// Pages with something to show, in tab order. Never empty: with nothing at all, the
    /// player page says "Nothing playing".
    var availablePages: [ExpandedPage] {
        var pages: [ExpandedPage] = []
        if nowPlaying.track != nil { pages.append(.player) }
        if !calendarModes.isEmpty { pages.append(.calendar) }
        if linear.isConnected { pages.append(.tasks) }
        if settings.showSystemPage { pages.append(.system) }
        if !clipboardModes.isEmpty { pages.append(.clipboard) }
        if settings.isEnabled(.agents) { pages.append(.agents) }
        return pages.isEmpty ? [.player] : pages
    }

    /// The page actually on screen: the chosen one if it still has content, else the first.
    var visiblePage: ExpandedPage {
        let pages = availablePages
        return pages.contains(page) ? page : pages[0]
    }

    /// Tabs only appear when there is a real choice.
    var showsPageTabs: Bool {
        availablePages.count > 1
    }

    /// Where the island opens: a meeting about to start wins, then what is playing, then
    /// deadlines, then the calendar.
    private var preferredPage: ExpandedPage {
        let pages = availablePages
        if calendar.imminentMeeting != nil, pages.contains(.calendar) { return .calendar }
        if !features.agents.approvals.isEmpty, pages.contains(.agents) { return .agents }
        if pages.contains(.player) { return .player }
        if pages.contains(.tasks), !linear.issues.isEmpty { return .tasks }
        return pages[0]
    }

    private var contentHeightForCurrentState: CGFloat {
        switch visiblePage {
        case .player:
            return nowPlaying.track != nil ? IslandLayout.playerHeight : IslandLayout.messageHeight
        case .calendar:
            let switchRow = calendarModes.count > 1 ? IslandLayout.pageSwitchHeight + IslandLayout.pageSwitchGap : 0
            if visibleCalendarMode == .reminders {
                let reminders = features.reminders
                return switchRow + (reminders.access == .granted
                    ? IslandLayout.remindersHeight(count: reminders.reminders.count)
                    : IslandLayout.messageHeight)
            }
            return switchRow + (calendar.access == .granted
                ? IslandLayout.calendarHeight(events: calendar.events.count)
                : IslandLayout.messageHeight)
        case .tasks:
            if case .failed = linear.status { return IslandLayout.messageHeight }
            let groups = TaskGroup.make(from: linear.issues,
                                        rowBudget: tasksExpanded ? .max : IslandLayout.compactTaskRows)
            let height = TaskGroup.height(of: groups)
            return tasksExpanded ? min(height, IslandLayout.expandedTasksMaxHeight) : height
        case .system:
            return IslandLayout.systemPageHeight(hasBattery: system.battery != nil)
        case .agents:
            return IslandLayout.agentsHeight(approvals: features.agents.approvals.count,
                                             sessions: features.agents.sessions.count)
        case .clipboard:
            let switchRow = clipboardModes.count > 1 ? IslandLayout.pageSwitchHeight + IslandLayout.pageSwitchGap : 0
            if visibleClipboardMode == .shelf { return switchRow + IslandLayout.shelfHeight }
            return switchRow + IslandLayout.clipboardHeight(setup: clipboard.access != .allowed,
                                                            pinned: clipboard.pinned.count, recent: clipboard.items.count)
        }
    }

    /// Re-derives the page height. While expanded the island resizes on the gentle spring
    /// (layout, no overshoot) as the content morphs — the sanctioned "height springs while the
    /// sub-views trade places" pairing.
    private func updateContentHeight(animated: Bool) {
        let height = contentHeightForCurrentState
        guard height != expandedContentHeight else { return }
        if animated && state == .expanded {
            Motion.perform(Motion.gentle) { expandedContentHeight = height }
        } else {
            expandedContentHeight = height
        }
    }

    /// The calendar page exists unless the user turned it off or denied calendar access.
    var calendarAvailable: Bool {
        settings.showCalendar && calendar.access != .denied
    }

    func show(_ page: ExpandedPage) {
        guard page != visiblePage, availablePages.contains(page) else { return }
        Motion.perform(Motion.snappy) {
            self.page = page
        }
    }

    // MARK: - Calendar tab and reminders

    /// The calendar tab's halves that are on: events (Settings › Island) and reminders
    /// (Settings › Features).
    var calendarModes: [CalendarMode] {
        (calendarAvailable ? [.events] : []) + (settings.isEnabled(.reminders) ? [.reminders] : [])
    }

    var visibleCalendarMode: CalendarMode {
        let modes = calendarModes
        return modes.contains(calendarMode) ? calendarMode : (modes.first ?? .events)
    }

    func showCalendarMode(_ mode: CalendarMode) {
        guard mode != visibleCalendarMode else { return }
        Motion.perform(Motion.snappy) { calendarMode = mode }
    }

    // MARK: - Clipboard tab and shelf

    /// The clipboard tab's halves that are on: the history (Settings › Island) and the shelf
    /// (Settings › Features).
    var clipboardModes: [ClipboardMode] {
        (settings.showClipboard ? [.clipboard] : []) + (settings.isEnabled(.shelf) ? [.shelf] : [])
    }

    var visibleClipboardMode: ClipboardMode {
        let modes = clipboardModes
        return modes.contains(clipboardMode) ? clipboardMode : (modes.first ?? .clipboard)
    }

    func showClipboardMode(_ mode: ClipboardMode) {
        guard mode != visibleClipboardMode else { return }
        Motion.perform(Motion.snappy) { clipboardMode = mode }
    }

    /// Files dragged over (or off) the open island: the shelf comes forward to take them.
    func setShelfTargeted(_ targeted: Bool) {
        guard targeted != shelfTargeted else { return }
        shelfTargeted = targeted
        guard targeted, clipboardModes.contains(.shelf) else { return }
        Motion.perform(Motion.snappy) {
            page = .clipboard
            clipboardMode = .shelf
        }
    }

    func shelfDropped(_ urls: [URL]) {
        shelfTargeted = false
        features.shelf.add(urls)
        Motion.perform(Motion.snappy) {
            page = .clipboard
            clipboardMode = .shelf
        }
    }

    /// The drag pasteboard's count when the mouse last went down, so a drag that started since
    /// can be told from what an old drag left behind.
    private var dragChangeCount = NSPasteboard(name: .drag).changeCount

    /// Files are being dragged right now (and the shelf is on).
    private var isDraggingFiles: Bool {
        guard settings.isEnabled(.shelf), NSEvent.pressedMouseButtons & 1 != 0 else { return false }
        let pasteboard = NSPasteboard(name: .drag)
        return pasteboard.changeCount != dragChangeCount && pasteboard.types?.contains(.fileURL) == true
    }

    /// "View more" on the tasks page: the list grows in place while the island stays open.
    func showMoreTasks() {
        guard !tasksExpanded else { return }
        tasksExpanded = true
        updateContentHeight(animated: true)
    }

    func openSettings() {
        collapse()
        onOpenSettings?()
    }

    func requestLowPowerMode() {
        onRequestLowPowerMode?()
    }

    /// One of the meeting reminder's buttons: join the call, ignore it, or be reminded in 5 min.
    func answerMeeting(_ meeting: UpcomingEvent, _ answer: MeetingAnswer) {
        switch answer {
        case .join: calendar.join(meeting)
        case .ignore: calendar.ignore(meeting)
        case .snooze: calendar.snooze(meeting)
        }
        activities.reminderAnswered()
    }

    /// The ☕ button in the notch row: on for the chosen time (Settings), or off.
    func toggleKeepAwake() {
        let keepAwake = features.keepAwake
        if keepAwake.isOn {
            keepAwake.turnOff()
        } else {
            let hours = settings.keepAwakeHours
            keepAwake.turnOn(keepingDisplayOn: settings.keepAwakeDisplay,
                             for: hours > 0 ? TimeInterval(hours) * 3600 : nil)
        }
    }

    /// Deny or Approve on an agent's request, from the notch.
    func answerAgent(_ approval: AgentApproval, approve: Bool?) {
        features.agents.answer(approval, approve: approve)
    }

    /// The 🎙 button in the notch row.
    func toggleVoice() {
        voice.toggle()
    }

    func expand() {
        guard state != .expanded else { return }
        // Hovering "Copied to clipboard" opens the history; files dragged to the notch, the shelf.
        let fromCopy = activities.current?.kind == .copied && clipboardModes.contains(.clipboard)
        let fromDrag = isDraggingFiles
        page = fromCopy || fromDrag ? .clipboard : preferredPage
        if fromCopy { clipboardMode = .clipboard }
        if fromDrag { clipboardMode = .shelf }
        features.shelf.pruneMissing()
        features.reminders.refresh()
        clipboard.refreshAccess()
        linear.refresh()
        system.start()
        updateContentHeight(animated: false)
        cancelPendingExpand()
        Motion.perform(Motion.islandGrow) {
            state = .expanded
        }
        if settings.hapticFeedback {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        onStateChange?(.expanded)
    }

    func collapse() {
        guard state != .collapsed else { return }
        cancelPendingCollapse()
        Motion.perform(Motion.islandShrink) {
            state = .collapsed
        }
        tasksExpanded = false
        system.stop()
        onStateChange?(.collapsed)
    }
}
