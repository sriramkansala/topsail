import CoreGraphics
import Foundation

/// What is being recorded: the screen (video, with the Mac's sound and the microphone if they are
/// on), or a call (audio only: the other side, from what the Mac plays, and you, from the
/// microphone).
enum RecordingKind: Equatable {
    case screen
    case call

    /// "Screen recording", "Call recording": under "Saved", and the start of a file's name.
    var title: String {
        switch self {
        case .screen: return String(localized: "Screen recording")
        case .call: return String(localized: "Call recording")
        }
    }

    var symbol: String {
        switch self {
        case .screen: return "rectangle.inset.filled.badge.record"
        case .call: return "phone.fill"
        }
    }
}

/// A recording already in the folder, for the Record page's "Previously" list.
struct RecentRecording: Identifiable, Equatable {
    let url: URL
    let kind: RecordingKind
    let date: Date
    var id: URL { url }
}

/// A recording that was saved, for the notice that says so.
struct SavedRecording: Equatable {
    let url: URL
    let kind: RecordingKind
    /// Recorded time, pauses left out.
    let duration: TimeInterval
}

/// The recorder's notices, which grow out of the notch like every other one.
enum RecorderNotice: Equatable {
    /// "Saved", with Show in Finder and Open.
    case saved(SavedRecording)
    /// A recording could not be started or saved.
    case failed(String)
    /// A call from the calendar was joined: record it? Always the user's choice.
    case offer(UpcomingEvent)
    /// Before the first call recording: recording laws may require telling everyone on the call.
    case consent(UpcomingEvent)

    /// Height of the card below the camera.
    var stageHeight: CGFloat {
        switch self {
        case .failed: return RecorderLayout.failedStageHeight
        case .saved, .offer, .consent: return RecorderLayout.cardStageHeight
        }
    }

    /// How long it stays (longer while the pointer is on it).
    var duration: TimeInterval {
        switch self {
        case .saved, .failed: return 6
        case .offer, .consent: return 30
        }
    }
}

enum RecorderError: LocalizedError {
    case noDisplay
    case screenRecordingDenied
    case microphoneDenied
    case nothingToRecord
    case nothingRecorded
    case cannotWrite(String)

    var errorDescription: String? {
        switch self {
        case .noDisplay: return String(localized: "There's no display to record.")
        case .screenRecordingDenied: return String(localized: "Topsail isn't allowed to record the screen.")
        case .microphoneDenied: return String(localized: "Topsail isn't allowed to use the microphone.")
        case .nothingToRecord: return String(localized: "Turn on the microphone or the Mac's sound to record a call.")
        case .nothingRecorded: return String(localized: "Nothing was recorded.")
        case .cannotWrite(let reason): return reason
        }
    }
}

/// The recorder's sizes in the island. The island's own (`IslandLayout`) are left alone; these
/// are the recorder's.
enum RecorderLayout {
    /// Each wing of the closed island while recording: the red dot on the left, the time on the
    /// right, with room for "1:02:34".
    static let wing: CGFloat = 64
    /// Between a wing's content and the island's edge.
    static let wingInset: CGFloat = 14
    static let dotSize: CGFloat = 8
    /// The countdown's digit, under the camera.
    static let countdownStageHeight: CGFloat = 40

    // Notices, below the camera (the meeting reminder's measures).
    static let tileSize: CGFloat = 34
    /// A line of what went wrong.
    static let failedStageHeight: CGFloat = IslandLayout.noticeTopGap + tileSize + IslandLayout.reminderInset
    /// What happened (or is asked) over a row of buttons, as the meeting reminder.
    static let cardStageHeight: CGFloat = IslandLayout.reminderStageHeight

    // The Record page in the open island.
    static let tileHeight: CGFloat = 52
    static let chipHeight: CGFloat = 22
    static let rowGap: CGFloat = 10
    static let buttonHeight: CGFloat = IslandLayout.reminderButtonHeight
    static let idleHeight: CGFloat = tileHeight + rowGap + chipHeight
    /// "Previously", and the newest recordings under it.
    static let previousLimit = 3
    static let previousHeaderHeight: CGFloat = 14
    static let previousRowHeight: CGFloat = 30
    static func previousHeight(count: Int) -> CGFloat {
        count == 0 ? 0 : rowGap + previousHeaderHeight + 4 + CGFloat(count) * previousRowHeight
    }
    static let recordingHeight: CGFloat = 30 + rowGap + buttonHeight
    static let messageHeight: CGFloat = 34 + rowGap + buttonHeight
}
