import CoreGraphics

/// Sizes of the expanded island. The model sizes the island from these and the views lay out
/// to them, so the black shape always hugs its content.
///
/// Expanded layout: the notch row (tabs left of the camera, gear right of it), then one page
/// of content below it.
enum IslandLayout {
    static let expandedWidth: CGFloat = 400
    /// Minimum width of each side of the notch row when expanded: room for up to four page tabs
    /// on the left and the mic and gear on the right, none of them under the camera. A fifth tab
    /// widens it (`expandedWing(tabs:)`).
    static let minimumExpandedWing: CGFloat = 110

    static let horizontalPadding: CGFloat = 16
    /// Inside a page tab; the notch row is inset by this much less, so tab icons line up with
    /// the page content below them.
    static let tabPadding: CGFloat = 4
    /// Every page tab is this wide, so the row's width is known before it is drawn.
    static let tabWidth: CGFloat = 22
    static let tabSpacing: CGFloat = 2
    /// Between the last tab and the camera.
    static let tabNotchGap: CGFloat = 4

    /// Each side of the open island: the minimum, or wide enough for `tabs` tabs left of the
    /// camera (four fit the minimum; five need 24 pt more a side).
    static func expandedWing(tabs: Int) -> CGFloat {
        let row = CGFloat(tabs) * tabWidth + CGFloat(max(0, tabs - 1)) * tabSpacing
        return max(minimumExpandedWing, horizontalPadding - tabPadding + row + tabNotchGap)
    }
    static let contentTopPadding: CGFloat = 6
    static let contentBottomPadding: CGFloat = 16
    /// A level in the open island's bottom margin sits this far up from the edge.
    static let levelIndicatorBottom: CGFloat = 6

    /// Width of the island during a voice note.
    static let voiceWidth: CGFloat = 560

    /// Each wing of the closed island while a koi swims under the notch (Koi pond).
    static let koiPassWing: CGFloat = 60
    /// The Koi pond page, below the notch row; with the margins the open island is 220 tall.
    static let pondHeight: CGFloat = 166

    static let expandedTopRadius: CGFloat = 14
    static let expandedBottomRadius: CGFloat = 24

    // Page heights
    static let playerHeight: CGFloat = 60
    /// One line of text: "Nothing playing", "No more events", "Show calendar".
    static let messageHeight: CGFloat = 24
    static let eventRowHeight: CGFloat = 28
    static let eventRowSpacing: CGFloat = 8
    static let maxEvents = 2

    // System page: a battery tile above CPU and memory tiles, then a line of smaller figures.
    static let systemTileRadius: CGFloat = 12
    static let systemTilePadding: CGFloat = 10
    static let systemTileGap: CGFloat = 8
    static let systemBatteryTileHeight: CGFloat = 50
    static let systemTileHeaderHeight: CGFloat = 14
    static let systemTileHeaderGap: CGFloat = 5
    static let systemTileBodyHeight: CGFloat = 26
    static let systemTileHeight: CGFloat = 8 + systemTileHeaderHeight + systemTileHeaderGap + systemTileBodyHeight + 8
    /// The per-core bars, standing on the CPU figure's baseline.
    static let systemMeterHeight: CGFloat = 19
    /// The memory bar.
    static let systemBarHeight: CGFloat = 7
    static let systemFooterGap: CGFloat = 9
    static let systemFooterHeight: CGFloat = 13

    static func systemPageHeight(hasBattery: Bool) -> CGFloat {
        (hasBattery ? systemBatteryTileHeight + systemTileGap : 0) + systemTileHeight + systemFooterGap + systemFooterHeight
    }

    /// Each wing of every popup beside the notch (charging, low battery, volume, a device, a
    /// deadline, a meeting): one width for all, the open island's, so hovering a popup only grows
    /// it downward. Now playing, which stays rather than pops up, keeps its narrow pill.
    static let activityWing: CGFloat = minimumExpandedWing

    // Low-battery notice, below the camera: the level over a hint on the left, the battery in a
    // pill on the right. iOS's proportions at about 0.83 scale, a Mac point being larger.
    static let noticePillSize = CGSize(width: 63, height: 38)
    /// Between the pill and the island's right and bottom edges.
    static let noticeInset: CGFloat = 10
    static let noticeLeading: CGFloat = 22
    static let noticeTopGap: CGFloat = 4
    static let noticeStageHeight: CGFloat = noticeTopGap + noticePillSize.height + noticeInset

    // Meeting reminder, below the camera: the call's colour, title and start over a row of
    // buttons (Remind me in 5 min on the left, Ignore and Join on the right).
    static let reminderInset: CGFloat = 14
    static let reminderHeaderHeight: CGFloat = 34
    static let reminderRowGap: CGFloat = 12
    static let reminderButtonHeight: CGFloat = 28
    static let reminderStageHeight: CGFloat = noticeTopGap + reminderHeaderHeight + reminderRowGap
        + reminderButtonHeight + reminderInset

    // A device connecting, below the camera: the device and its name on the left, its battery on
    // the right (each earbud and the case, or one level). Music stays beside the notch above it.
    static let deviceTileSize: CGFloat = 34
    static let deviceInset: CGFloat = 14
    static let deviceGaugeSize: CGFloat = 24
    static let deviceStageHeight: CGFloat = noticeTopGap + deviceTileSize + deviceInset

    // "Copied to clipboard", under the camera: the notch reaches a little lower and says so.
    static let copiedStageHeight: CGFloat = 24

    // Clipboard page: pinned items, then recent copies, one row each under a small header. Never
    // shorter than three rows, so one copy isn't a sliver; past five rows' height, it scrolls.
    static let clipboardHeaderHeight: CGFloat = 14
    static let clipboardHeaderGap: CGFloat = 6
    static let clipboardRowHeight: CGFloat = 28
    static let clipboardRowSpacing: CGFloat = 2
    static let clipboardSectionGap: CGFloat = 10
    /// "Remember what you copy" and its button, until Topsail may read the clipboard.
    static let clipboardSetupHeight: CGFloat = 40
    static let clipboardMinHeight: CGFloat = clipboardSection(rows: 3)
    static let clipboardMaxHeight: CGFloat = clipboardSection(rows: 5)

    /// A header and `rows` rows; nothing for no rows.
    static func clipboardSection(rows: Int) -> CGFloat {
        guard rows > 0 else { return 0 }
        return clipboardHeaderHeight + clipboardHeaderGap + CGFloat(rows) * clipboardRowHeight
            + CGFloat(rows - 1) * clipboardRowSpacing
    }

    /// Everything the page holds, stacked: the setup row, the pinned section, the recent one.
    static func clipboardNaturalHeight(setup: Bool, pinned: Int, recent: Int) -> CGFloat {
        let parts = [setup ? clipboardSetupHeight : 0, clipboardSection(rows: pinned), clipboardSection(rows: recent)]
            .filter { $0 > 0 }
        return parts.reduce(0, +) + CGFloat(max(0, parts.count - 1)) * clipboardSectionGap
    }

    static func clipboardHeight(setup: Bool, pinned: Int, recent: Int) -> CGFloat {
        min(max(clipboardNaturalHeight(setup: setup, pinned: pinned, recent: recent), clipboardMinHeight),
            clipboardMaxHeight)
    }

    // Apple Reminders, on the calendar tab: a row each (up to four), then a row to add one.
    static let remindersRowHeight: CGFloat = 22
    static let remindersRowSpacing: CGFloat = 4
    static let maxReminders = 4

    static func remindersHeight(count: Int) -> CGFloat {
        let rows = CGFloat(min(count, maxReminders) + 1)
        return rows * remindersRowHeight + (rows - 1) * remindersRowSpacing
    }

    // Teleprompter: the open island, wider, holding the script over a row of controls.
    static let teleprompterWidth: CGFloat = 500
    static let teleprompterHeight: CGFloat = 168
    /// How far it can be pulled down, from the handle below it.
    static let teleprompterHeightRange: ClosedRange<CGFloat> = 120...400
    /// The handle hangs this far below the island's bottom edge.
    static let teleprompterHandleGap: CGFloat = 4
    static let teleprompterControlsHeight: CGFloat = 30
    /// The script's first line starts this far below the top edge.
    static let teleprompterLeadIn: CGFloat = 22

    // An agent asking before a command, below the camera: who and where, the command, then a
    // countdown with Deny and Approve.
    static let approvalHeaderHeight: CGFloat = 30
    /// Three lines: what's approved is always shown whole (`AgentApproval.isReviewable`).
    static let approvalDetailHeight: CGFloat = 44
    static let approvalGap: CGFloat = 10
    static let approvalStageHeight: CGFloat = noticeTopGap + approvalHeaderHeight + approvalGap
        + approvalDetailHeight + 12 + approvalGap + reminderButtonHeight + reminderInset

    // Another app's notification, below the camera: its icon, who it's from, two lines of text.
    static let notificationIconSize: CGFloat = 36
    static let notificationHeight: CGFloat = 52
    static let notificationStageHeight: CGFloat = noticeTopGap + notificationHeight + noticeInset

    // Apps page: what other apps show; it scrolls past this.
    static let appsHeight: CGFloat = 168

    // Agents page: requests waiting for an answer, then sessions.
    static let agentRowHeight: CGFloat = 34
    static let approvalRowHeight: CGFloat = 80
    static let agentRowSpacing: CGFloat = 6
    static let agentsMaxHeight: CGFloat = 4 * agentRowHeight + 3 * agentRowSpacing

    static func agentsNaturalHeight(approvals: Int, sessions: Int) -> CGFloat {
        let rows = approvals + sessions
        guard rows > 0 else { return 0 }
        return CGFloat(approvals) * approvalRowHeight + CGFloat(sessions) * agentRowHeight
            + CGFloat(rows - 1) * agentRowSpacing
    }

    static func agentsHeight(approvals: Int, sessions: Int) -> CGFloat {
        let natural = agentsNaturalHeight(approvals: approvals, sessions: sessions)
        return natural == 0 ? messageHeight : min(natural, max(agentsMaxHeight, approvalRowHeight))
    }

    // The clipboard tab's Clipboard / Shelf switch, when both are on.
    static let pageSwitchHeight: CGFloat = 22
    static let pageSwitchGap: CGFloat = 8

    // File shelf: a row of tiles (thumbnail over name) under a header; four fit, more scroll.
    static let shelfThumbnailSize: CGFloat = 48
    static let shelfTileWidth: CGFloat = 76
    static let shelfTileHeight: CGFloat = 88
    static let shelfVisibleTiles = 4
    static let shelfHeight: CGFloat = clipboardHeaderHeight + clipboardHeaderGap + shelfTileHeight

    // Tasks page: issues grouped under their workflow state, as in Linear's "My issues".
    static let taskRowHeight: CGFloat = 18
    static let taskHeaderHeight: CGFloat = 14
    static let taskRowSpacing: CGFloat = 5
    static let taskGroupSpacing: CGFloat = 8
    /// Rows shown before "View more" (each state heading counts as a row).
    static let compactTaskRows = 5
    /// Tallest the list grows after "View more"; beyond this it scrolls.
    static let expandedTasksMaxHeight: CGFloat = 170

    /// Height of `rows` list rows (calendar and tasks share one row size), or one message line.
    static func listHeight(rows: Int) -> CGFloat {
        guard rows > 0 else { return messageHeight }
        return CGFloat(rows) * eventRowHeight + CGFloat(rows - 1) * eventRowSpacing
    }

    static func calendarHeight(events: Int) -> CGFloat {
        listHeight(rows: min(events, maxEvents))
    }
}
