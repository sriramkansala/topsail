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

    // The panel never resizes: it must fit the largest island — a voice note in review (560 wide,
    // up to ~700 tall) — plus the ears and the shadow. Its transparent area passes clicks through.
    private static let panelSize = CGSize(width: 700, height: 820)

    init(settings: AppSettings, linear: LinearService, calendar: CalendarService, clipboard: ClipboardHistory,
         openSettings: @escaping () -> Void) {
        let nowPlaying = NowPlayingService()
        let activities = ActivityCenter()
        activities.isAllowed = { [weak settings, weak calendar] kind in
            // A call's reminder also has to still be due: not answered, not put off, joinable.
            if case .meetingReminder(let meeting) = kind, calendar?.isReminderDue(meeting) != true { return false }
            return settings?.allows(kind) ?? true
        }
        calendar.onReminder = { [weak activities] meeting in activities?.post(.meetingReminder(meeting)) }
        let voice = VoiceNoteController(linear: linear)
        let batteryMonitor = BatteryMonitor(center: activities)
        let system = SystemMonitor(pluggedInAt: { [weak batteryMonitor] in batteryMonitor?.pluggedInAt })
        let model = NotchViewModel(nowPlaying: nowPlaying, activities: activities, calendar: calendar,
                                   linear: linear, voice: voice, system: system, clipboard: clipboard,
                                   settings: settings)
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
            }
        }
        activitySubscription = activities.$current.sink { [weak self] activity in
            guard let self else { return }
            self.updateMouseEvents(state: self.model.state, activity: activity)
        }
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
