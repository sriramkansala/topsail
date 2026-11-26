import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: NotchWindowController?
    private let settings = AppSettings()
    private let linear = LinearService()
    private let calendar = CalendarService()
    private let clipboard = ClipboardHistory()
    private let features = FeatureServices()
    private lazy var settingsWindowController = SettingsWindowController(settings: settings, linear: linear,
                                                                         calendar: calendar, clipboard: clipboard,
                                                                         features: features)
    private var statusItem: NSStatusItem?
    private var voiceItem: NSMenuItem?
    private var teleprompterItem: NSMenuItem?
    private var updateItem: NSMenuItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMainMenu()

        let controller = NotchWindowController(settings: settings, linear: linear, calendar: calendar,
                                               clipboard: clipboard, features: features) { [weak self] in
            self?.showSettings()
        }
        windowController = controller
        controller.showWindow(nil)

        buildStatusItem()

        // The voice-note shortcut works from anywhere while Topsail runs, once Linear is connected.
        let shortcuts = VoiceShortcutManager.shared
        shortcuts.onPress = { [weak controller] in controller?.model.voice.toggle() }
        linear.$status
            .map { $0 == .connected }
            .removeDuplicates()
            .sink { [weak self] connected in
                shortcuts.isEnabled = connected
                self?.voiceItem?.isHidden = !connected
            }
            .store(in: &cancellables)

        settings.publisher(for: .autoUpdates)
            .sink { [weak self] on in if on { self?.features.updater.start() } else { self?.features.updater.stop() } }
            .store(in: &cancellables)
        features.updater.$state
            .sink { [weak self] state in
                if case .ready = state { self?.updateItem?.isHidden = false } else { self?.updateItem?.isHidden = true }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .topsailStartTeleprompter)
            .sink { [weak self] _ in self?.startTeleprompter() }
            .store(in: &cancellables)
        settings.publisher(for: .teleprompter)
            .sink { [weak self] on in
                self?.teleprompterItem?.isHidden = !on
                if !on { self?.features.teleprompter.stop() }
            }
            .store(in: &cancellables)

        // With no Dock icon, and the menu bar item easily hidden behind the notch, the first
        // launch opens Settings so it is clear Topsail is running and where to find it.
        if !UserDefaults.standard.bool(forKey: Self.launchedBeforeKey) {
            UserDefaults.standard.set(true, forKey: Self.launchedBeforeKey)
            showSettings()
        }

        #if DEBUG
        // Debug builds only: plays a scripted voice note through the island, no mic or Linear.
        if CommandLine.arguments.contains("--voice-demo") {
            Task { await controller.model.voice.runDemo() }
        }
        #endif

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.windowController?.reposition()
            }
            .store(in: &cancellables)
    }

    /// `topsail://settings` opens the settings window (e.g. `open topsail://settings` in Terminal).
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "topsail" {
            switch url.host {
            case "settings": showSettings()
            #if DEBUG
            // Debug builds only: `open topsail://preview/low-battery` (or `/charging`, `/meeting`, `/airpods`, `/headphones`, `/copied`, `/koi`) shows that
            // activity now, without draining the battery or unplugging.
            case "preview": windowController?.preview(url.lastPathComponent)
            #endif
            default: break
            }
        }
    }

    private static let launchedBeforeKey = "launchedBefore"

    func applicationWillTerminate(_ notification: Notification) {
        windowController?.model.stopTracking()
        features.keepAwake.turnOff()
        if settings.isEnabled(.autoUpdates) { features.updater.installIfReady() }
    }

    private func buildStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            let image = NSImage(systemSymbolName: "capsule.portrait.fill", accessibilityDescription: "Topsail")
            image?.isTemplate = true
            button.image = image
        }

        let menu = NSMenu()

        let aboutItem = NSMenuItem(
            title: String(localized: "About Topsail"),
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        let voiceItem = NSMenuItem(
            title: String(localized: "Record Voice Note"),
            action: #selector(recordVoiceNote),
            keyEquivalent: ""
        )
        voiceItem.target = self
        voiceItem.isHidden = true
        menu.addItem(voiceItem)
        self.voiceItem = voiceItem

        let teleprompterItem = NSMenuItem(
            title: String(localized: "Start Teleprompter"),
            action: #selector(startTeleprompter),
            keyEquivalent: ""
        )
        teleprompterItem.target = self
        teleprompterItem.isHidden = !settings.isEnabled(.teleprompter)
        menu.addItem(teleprompterItem)
        self.teleprompterItem = teleprompterItem

        let updateItem = NSMenuItem(title: String(localized: "Restart to Update"), action: #selector(restartToUpdate),
                                    keyEquivalent: "")
        updateItem.target = self
        updateItem.isHidden = true
        menu.addItem(updateItem)
        self.updateItem = updateItem

        let settingsItem = NSMenuItem(
            title: String(localized: "Settings…"),
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: String(localized: "Quit Topsail"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    /// Topsail shows no menu bar of its own, but text fields still take their key equivalents from
    /// the main menu: ⌘V to paste a Linear key, ⌘Z while renaming a task, ⌘W to close Settings.
    /// No Quit here: a voice note can hold the keyboard while another app is in front, and ⌘Q
    /// meant for that app must not quit Topsail.
    private func buildMainMenu() {
        let main = NSMenu()
        main.addItem(NSMenuItem())  // the application menu, never shown

        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: String(localized: "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: String(localized: "Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem()
        editItem.submenu = edit
        main.addItem(editItem)

        let window = NSMenu(title: "Window")
        window.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        let windowItem = NSMenuItem()
        windowItem.submenu = window
        main.addItem(windowItem)

        NSApp.mainMenu = main
    }

    @objc private func restartToUpdate() {
        features.updater.restartToUpdate()
    }

    @objc private func startTeleprompter() {
        windowController?.model.startTeleprompter()
    }

    @objc private func recordVoiceNote() {
        windowController?.model.voice.toggle()
    }

    @objc private func showSettings() {
        settingsWindowController.show()
    }

    @objc private func showAbout() {
        NSApp.activate()
        NSApp.orderFrontStandardAboutPanel(nil)
    }
}
