#if DEBUG
import AppKit

/// The continuity suite's test mode (debug builds only; see `docs/continuity/matrix.md`).
///
/// Launched with `--continuity`, Topsail shows made-up data only: every real source (what is
/// playing, the calendar, the clipboard, Linear, agents, notifications, the battery and volume
/// keys) stays switched off, preferences are a throwaway set, and the pointer is the test's own.
/// `topsail://test/<cell-id>` then puts the island in a cell's starting state and fires its
/// triggers with exact timing while `MotionTracer` writes what moved, frame by frame.
enum Continuity {
    static let isActive = CommandLine.arguments.contains("--continuity")

    /// Throwaway preferences, emptied at every launch, so a run never reads or changes the user's.
    nonisolated(unsafe) static let defaults: UserDefaults = {
        let name = "app.topsail.continuity"
        let defaults = UserDefaults(suiteName: name) ?? .standard
        defaults.removePersistentDomain(forName: name)
        return defaults
    }()

    /// Reduce Motion, as the cell under test wants it (the system setting is left alone).
    nonisolated(unsafe) static var reduceMotion = false
    /// Where the test's pointer is, in screen coordinates; nil when it is far from the island.
    nonisolated(unsafe) static var pointer: CGPoint?
    /// True while a cell's starting state is being put in place: every change lands at once.
    nonisolated(unsafe) static var settingUp = false

    /// The value after `--name` on the command line.
    static func argument(_ name: String) -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }
}
#endif
