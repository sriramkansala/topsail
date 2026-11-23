import AppKit
import Combine
import SwiftUI

@MainActor
final class NotchWindowController: NSWindowController {
    let model: NotchViewModel
    private let batteryMonitor: BatteryMonitor
    private let audioMonitor: AudioMonitor
    private let volumeKeys: VolumeKeyInterceptor
    private var activitySubscription: AnyCancellable?
    private var clipboardSubscription: AnyCancellable?
    private var featureSubscriptions = Set<AnyCancellable>()

    // The panel never resizes: it must fit the largest island — a voice note in review (560 wide,
    // up to ~700 tall) — plus the ears and the shadow. Its transparent area passes clicks through.
    private static let panelSize = CGSize(width: 700, height: 820)

    init(settings: AppSettings, linear: LinearService, calendar: CalendarService, clipboard: ClipboardHistory,
         features: FeatureServices, openSettings: @escaping () -> Void) {
        let nowPlaying = NowPlayingService()
        let activities = ActivityCenter()
        activities.isAllowed = { [weak settings, weak calendar] kind in
            // A call's reminder also has to still be due: not answered, not put off, joinable.
            if case .meetingReminder(let meeting) = kind, calendar?.isReminderDue(meeting) != true { return false }
            // An agent's request still waiting for an answer.
            if case .agentApproval(let approval) = kind, features.agents.isPending(approval) != true { return false }
            return settings?.allows(kind) ?? true
        }
        calendar.onReminder = { [weak activities] meeting in activities?.post(.meetingReminder(meeting)) }
        let voice = VoiceNoteController(linear: linear)
        let batteryMonitor = BatteryMonitor(center: activities)
        let system = SystemMonitor(pluggedInAt: { [weak batteryMonitor] in batteryMonitor?.pluggedInAt })
        let model = NotchViewModel(nowPlaying: nowPlaying, activities: activities, calendar: calendar,
                                   linear: linear, voice: voice, system: system, clipboard: clipboard,
                                   features: features, settings: settings)
        clipboard.onCopy = { [weak activities] in activities?.post(.copied) }
        voice.onPresent = { [weak model] in model?.presentVoice() }
        linear.onDue = { [weak activities] issues in
            guard let first = issues.first else { return }
            let title = issues.count == 1 ? first.title : "\(issues.count) tasks"
            activities?.post(.taskDue(title: title, overdue: issues.contains { $0.isOverdue() }))
        }
        self.model = model
        model.onOpenSettings = openSettings
        model.onRequestLowPowerMode = { [weak batteryMonitor] in batteryMonitor?.requestLowPowerMode() }
        self.batteryMonitor = batteryMonitor
        audioMonitor = AudioMonitor(center: activities)
        volumeKeys = VolumeKeyInterceptor(settings: settings, center: activities, nowPlaying: nowPlaying)

        let panel = NotchPanel(contentRect: .zero)
        super.init(window: panel)

        guard let panel = self.window as? NotchPanel else {
            fatalError("NotchWindowController window is not a NotchPanel")
        }

        let hostingView = NSHostingView(rootView: NotchView(model: model, nowPlaying: nowPlaying))
        hostingView.sizingOptions = []
        hostingView.frame = NSRect(origin: .zero, size: Self.panelSize)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        // ⏎ / Esc and renaming a task need the keyboard; the panel takes it without
        // activating Clove (it is non-activating), so the app the user was in stays in front.
        model.onVoicePresent = { [weak self] in
            self?.window?.makeKey()
        }

        model.onStateChange = { [weak self] state in
            guard let self else { return }
            self.updateMouseEvents(state: state, activity: activities.current)
            if state == .expanded {
                calendar.refresh()
            } else {
                self.giveUpKeyboard()
            }
        }
        activitySubscription = activities.$current.sink { [weak self] activity in
            guard let self else { return }
            self.updateMouseEvents(state: self.model.state, activity: activity)
        }
        // Switched-off-by-default features: each service stops when its feature is turned off.
        features.keepAwake.onChange = { [weak activities] on in activities?.post(.keepAwake(on: on)) }
        settings.publisher(for: .keepAwake)
            .sink { [weak features] on in if !on { features?.keepAwake.turnOff() } }
            .store(in: &featureSubscriptions)
        let agents = features.agents
        agents.onApproval = { [weak activities] in activities?.post(.agentApproval($0)) }
        agents.onApprovalClosed = { [weak activities] in activities?.withdraw(.agentApproval($0)) }
        agents.onFinished = { [weak activities] session in
            activities?.post(.agentFinished(agent: session.agent, project: session.project))
        }
        settings.publisher(for: .agents)
            .sink { [weak agents] on in if on { agents?.start() } else { agents?.stop() } }
            .store(in: &featureSubscriptions)
        Publishers.CombineLatest3(settings.$agentsAutoApprove, settings.$agentsAskInNotch, settings.$agentsWaitSeconds)
            .sink { [weak agents] autoApprove, ask, wait in
                agents?.autoApproveReadOnly = autoApprove
                agents?.askInNotch = ask
                agents?.waitSeconds = TimeInterval(wait)
            }
            .store(in: &featureSubscriptions)
        Publishers.CombineLatest3(settings.$appsTerminal, settings.$appsChrome, settings.$appsYouTube)
            .sink { [weak apps = features.apps] terminal, chrome, youTube in
                apps?.showsTerminal = terminal
                apps?.showsChrome = chrome
                apps?.showsYouTube = youTube
            }
            .store(in: &featureSubscriptions)
        let mirror = features.notifications
        mirror.onNotification = { [weak activities] in activities?.post(.notification($0)) }
        settings.$notificationApps.sink { [weak mirror] in mirror?.apps = $0 }.store(in: &featureSubscriptions)
        settings.publisher(for: .notifications)
            .sink { [weak mirror] on in if on { mirror?.start() } else { mirror?.stop() } }
            .store(in: &featureSubscriptions)
        settings.publisher(for: .reminders)
            .sink { [weak features] on in
                if on { features?.reminders.start() } else { features?.reminders.stop() }
            }
            .store(in: &featureSubscriptions)

        // Copies are watched while either the history or the "Copied" popup is on.
        clipboardSubscription = Publishers.CombineLatest(settings.$showClipboard, settings.$showCopyActivity)
            .sink { [weak clipboard] keepsHistory, announces in
                guard let clipboard else { return }
                clipboard.keepsHistory = keepsHistory
                if keepsHistory || announces { clipboard.start() } else { clipboard.stop() }
            }

        reposition()
        model.startTracking()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Typing in the island (a reminder, a voice note's rename) made the panel key; once the
    /// island closes, keystrokes must go back to the app the user is in, not to Clove. Ordering
    /// the panel out and in drops key status without activating anything.
    private func giveUpKeyboard() {
        guard let window, window.isKeyWindow else { return }
        window.orderOut(nil)
        window.orderFrontRegardless()
    }

    /// A collapsed island lets clicks through to the menu bar, unless it is showing a notice that
    /// can be clicked.
    private func updateMouseEvents(state: NotchViewModel.IslandState, activity: TransientActivity?) {
        window?.ignoresMouseEvents = state == .collapsed && activity?.kind.isClickable != true
    }

    #if DEBUG
    func preview(_ activity: String) {
        let lowPowerMode: LowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled ? .on : .off
        switch activity {
        case "low-battery": model.activities.post(.lowBattery(level: 20, lowPowerMode: lowPowerMode))
        case "charging": model.activities.post(.charging(level: 80))
        case "meeting":
            // A made-up call a minute away; Join opens Zoom's test page.
            let start = Date().addingTimeInterval(60)
            let meeting = UpcomingEvent(id: "preview-\(start.timeIntervalSince1970)", title: "Design review",
                                        start: start, end: start.addingTimeInterval(30 * 60), isAllDay: false,
                                        color: .purple, joinURL: URL(string: "https://zoom.us/test"))
            model.activities.post(.meetingReminder(meeting))
        case "airpods":
            model.activities.post(.audioDevice(name: "AirPods Pro",
                                               battery: DeviceBattery(left: 80, right: 75, chargingCase: 60)))
        case "headphones":
            // The App Store build's card: no battery.
            model.activities.post(.audioDevice(name: "Headphones", battery: nil))
        case "copied": model.activities.post(.copied)
        default: break
        }
    }
    #endif

    func reposition() {
        guard let screen = NotchGeometry.targetScreen(),
              let panel = self.window as? NotchPanel else { return }

        let notch = NotchGeometry.notchRect(on: screen)
        model.update(notchRect: notch)

        let size = Self.panelSize
        let originX = notch.midX - size.width / 2
        let originY = screen.frame.maxY - size.height

        panel.setFrame(
            NSRect(x: originX, y: originY, width: size.width, height: size.height),
            display: true
        )

        panel.orderFrontRegardless()
    }
}
