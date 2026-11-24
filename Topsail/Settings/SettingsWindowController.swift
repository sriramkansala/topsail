import AppKit
import SwiftUI

/// The settings window. Topsail is an agent app with no Dock icon, so the app is activated
/// explicitly to bring the window in front of other apps.
@MainActor
final class SettingsWindowController: NSWindowController {
    private let settings: AppSettings

    init(settings: AppSettings, linear: LinearService, calendar: CalendarService, clipboard: ClipboardHistory,
         features: FeatureServices) {
        self.settings = settings
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: SettingsStyle.windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Topsail Settings"
        window.isReleasedWhenClosed = false
        // The sidebar and the page run under the title bar; the empty toolbar sets the close button
        // in, clear of the sidebar's corner, and gives the window its larger corners.
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.toolbar = NSToolbar()
        window.toolbarStyle = .unified
        let host = NSHostingView(rootView: SettingsView(settings: settings, linear: linear, calendar: calendar,
                                                          clipboard: clipboard, features: features))
        // The window sizes the view, not the other way round.
        host.sizingOptions = []
        window.contentView = host
        // Taller or shorter, never wider.
        window.contentMinSize = CGSize(width: SettingsStyle.windowSize.width, height: SettingsStyle.minimumHeight)
        window.contentMaxSize = CGSize(width: SettingsStyle.windowSize.width, height: SettingsStyle.maximumHeight)
        window.setContentSize(SettingsStyle.windowSize)
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func show() {
        settings.reloadLaunchAtLogin()
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
        // macOS may decline the activation request when Topsail is opened from the background
        // (e.g. `open topsail://settings`), which would leave the window ordered out.
        window?.orderFrontRegardless()
    }
}
