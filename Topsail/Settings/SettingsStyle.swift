import AppKit
import SwiftUI

/// Settings' measures and colours: shadcn's colour roles and Fluid Functionalism's sizes, on a
/// 4 pt grid, in light and dark. Every number in a Settings view comes from here.
enum SettingsStyle {
    // MARK: Window

    static let windowSize = CGSize(width: 820, height: 640)
    static let minimumHeight: CGFloat = 480
    static let maximumHeight: CGFloat = 1000

    // MARK: Sidebar

    static let sidebarWidth: CGFloat = 200
    /// The sidebar floats this far from the window's edges.
    static let sidebarInset: CGFloat = 8
    /// Concentric with the window's own corners.
    static let sidebarRadius: CGFloat = 18
    static let sidebarPadding: CGFloat = 8
    /// Below the close button.
    static let sidebarTop: CGFloat = 48
    static let sidebarRowHeight: CGFloat = 32
    static let sidebarRowGap: CGFloat = 2
    /// Nested in the sidebar's corner: 18 - 8.
    static let sidebarRowRadius: CGFloat = 10

    // MARK: Page

    static let pagePadding: CGFloat = 24
    static let headerTop: CGFloat = 18
    static let headerBottom: CGFloat = 14
    static let sectionGap: CGFloat = 28
    static let headingGap: CGFloat = 8

    // MARK: Cards and rows

    static let cardRadius: CGFloat = 12
    static let rowHorizontal: CGFloat = 16
    static let rowVertical: CGFloat = 12
    static let rowMinHeight: CGFloat = 44
    /// Text never comes closer to a control than this.
    static let rowGap: CGFloat = 24
    static let textGap: CGFloat = 2
    static let iconSize: CGFloat = 28
    static let iconRadius: CGFloat = 7
    static let iconGap: CGFloat = 12
    static let panelRadius: CGFloat = 8
    static let statusDot: CGFloat = 6
    /// Where a row's text begins when it has an icon; what belongs to the row lines up with it.
    static let textInset: CGFloat = rowHorizontal + iconSize + iconGap

    // MARK: Controls

    static let controlHeight: CGFloat = 28
    static let controlRadius: CGFloat = 8
    static let controlPadding: CGFloat = 12
    static let fieldPadding: CGFloat = 10

    // MARK: Type

    static let title = Font.system(size: 16, weight: .semibold)
    static let heading = Font.system(size: 13, weight: .semibold)
    static let body = Font.system(size: 13)
    static let label = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 12)
    static let control = Font.system(size: 12, weight: .medium)
    /// Adds to a caption's own leading, for 16 pt lines.
    static let captionSpacing: CGFloat = 1.5

    // MARK: Colour roles

    static let background = adaptive(light: NSColor(white: 0.965, alpha: 1), dark: NSColor(white: 0.10, alpha: 1))
    static let card = adaptive(light: .white, dark: NSColor(white: 1, alpha: 0.045))
    static let sidebar = adaptive(light: NSColor(white: 1, alpha: 0.75), dark: NSColor(white: 1, alpha: 0.045))
    static let panel = adaptive(light: NSColor(white: 0, alpha: 0.025), dark: NSColor(white: 1, alpha: 0.03))
    static let border = adaptive(light: NSColor(white: 0, alpha: 0.09), dark: NSColor(white: 1, alpha: 0.09))
    static let foreground = adaptive(light: NSColor(white: 0.09, alpha: 1), dark: NSColor(white: 0.98, alpha: 1))
    static let muted = adaptive(light: NSColor(white: 0.42, alpha: 1), dark: NSColor(white: 0.64, alpha: 1))
    static let hover = adaptive(light: NSColor(white: 0, alpha: 0.04), dark: NSColor(white: 1, alpha: 0.06))
    static let selected = adaptive(light: NSColor(white: 0, alpha: 0.07), dark: NSColor(white: 1, alpha: 0.10))
    static let tint = adaptive(light: NSColor(white: 0, alpha: 0.06), dark: NSColor(white: 1, alpha: 0.10))
    static let tintHover = adaptive(light: NSColor(white: 0, alpha: 0.09), dark: NSColor(white: 1, alpha: 0.15))
    static let field = adaptive(light: .white, dark: NSColor(white: 0, alpha: 0.22))
    static let fieldBorder = adaptive(light: NSColor(white: 0, alpha: 0.14), dark: NSColor(white: 1, alpha: 0.15))
    static let fieldFocus = adaptive(light: NSColor(white: 0, alpha: 0.40), dark: NSColor(white: 1, alpha: 0.45))
    static let track = adaptive(light: NSColor(white: 0, alpha: 0.14), dark: NSColor(white: 1, alpha: 0.18))
    static let trackHover = adaptive(light: NSColor(white: 0, alpha: 0.20), dark: NSColor(white: 1, alpha: 0.25))
    static let warning = adaptive(light: NSColor(red: 0.72, green: 0.40, blue: 0.00, alpha: 1),
                                  dark: NSColor(red: 1.00, green: 0.70, blue: 0.28, alpha: 1))
    static let success = adaptive(light: NSColor(red: 0.09, green: 0.55, blue: 0.25, alpha: 1),
                                  dark: NSColor(red: 0.30, green: 0.82, blue: 0.48, alpha: 1))
    static let destructive = adaptive(light: NSColor(red: 0.78, green: 0.15, blue: 0.15, alpha: 1),
                                      dark: NSColor(red: 1.00, green: 0.45, blue: 0.42, alpha: 1))

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }
}
