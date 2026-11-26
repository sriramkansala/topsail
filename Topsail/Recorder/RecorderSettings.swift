import AppKit
import AVFoundation
import Combine

/// The recorder's preferences (Settings › Features › Screen and call recorder), kept apart from
/// `AppSettings` so the recorder stays in its own files.
@MainActor
final class RecorderSettings: ObservableObject {
    enum Format: String, CaseIterable {
        case mov
        case mp4

        var fileType: AVFileType { self == .mov ? .mov : .mp4 }
    }

    private let defaults = UserDefaults.standard

    /// Screen recordings are saved as QuickTime movies or MPEG-4. Calls are always .m4a.
    @Published var format: Format { didSet { defaults.set(format.rawValue, forKey: Key.format) } }
    /// Your voice: with the screen, and as your side of a call.
    @Published var microphone: Bool { didSet { defaults.set(microphone, forKey: Key.microphone) } }
    /// What the Mac plays: with the screen, and the other side of a call.
    @Published var systemAudio: Bool { didSet { defaults.set(systemAudio, forKey: Key.systemAudio) } }
    /// Your voice and the Mac's sound in two tracks instead of one mixed track.
    @Published var separateTracks: Bool { didSet { defaults.set(separateTracks, forKey: Key.separateTracks) } }
    /// After joining a call from the meeting reminder, ask whether to record it.
    @Published var offerForCalls: Bool { didSet { defaults.set(offerForCalls, forKey: Key.offerForCalls) } }
    /// The island shows up in screen recordings (it's left out by default).
    @Published var showsIsland: Bool { didSet { defaults.set(showsIsland, forKey: Key.showsIsland) } }
    /// The display to record; 0 = the one with the island.
    @Published var displayID: CGDirectDisplayID { didSet { defaults.set(Int(displayID), forKey: Key.displayID) } }
    /// Where recordings are saved.
    @Published private(set) var folder: URL
    /// The recording-laws reminder was shown and answered, before the first call recording.
    var consentShown: Bool {
        get { defaults.bool(forKey: Key.consentShown) }
        set { defaults.set(newValue, forKey: Key.consentShown) }
    }

    private enum Key {
        static let format = "recorder.format"
        static let microphone = "recorder.microphone"
        static let systemAudio = "recorder.systemAudio"
        static let separateTracks = "recorder.separateTracks"
        static let offerForCalls = "recorder.offerForCalls"
        static let showsIsland = "recorder.showsIsland"
        static let displayID = "recorder.displayID"
        static let folderBookmark = "recorder.folderBookmark"
        static let consentShown = "recorder.consentShown"
    }

    init() {
        defaults.register(defaults: [
            Key.format: Format.mov.rawValue,
            Key.microphone: true,
            Key.systemAudio: true,
            Key.separateTracks: false,
            Key.offerForCalls: true,
            Key.showsIsland: false,
            Key.displayID: 0,
        ])
        format = Format(rawValue: defaults.string(forKey: Key.format) ?? "") ?? .mov
        microphone = defaults.bool(forKey: Key.microphone)
        systemAudio = defaults.bool(forKey: Key.systemAudio)
        separateTracks = defaults.bool(forKey: Key.separateTracks)
        offerForCalls = defaults.bool(forKey: Key.offerForCalls)
        showsIsland = defaults.bool(forKey: Key.showsIsland)
        displayID = CGDirectDisplayID(clamping: defaults.integer(forKey: Key.displayID))
        folder = Self.defaultFolder
        #if DEBUG
        if Continuity.isActive { return }  // continuity tests: the default folder, never the user's own
        #endif
        if let chosen = resolveBookmark() { folder = chosen }
    }

    // MARK: The folder

    /// ~/Movies/Topsail, in the real home folder even under the App Sandbox (whose own home is
    /// its container); the App Store build may write there with the Movies entitlement.
    static var defaultFolder: URL {
        let home = getpwuid(getuid()).flatMap { String(validatingCString: $0.pointee.pw_dir) }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.homeDirectoryForCurrentUser
        return home.appending(path: "Movies", directoryHint: .isDirectory)
            .appending(path: "Topsail", directoryHint: .isDirectory)
    }

    var isDefaultFolder: Bool { folder.standardizedFileURL == Self.defaultFolder.standardizedFileURL }

    /// Where recordings go, as Finder names it: "Movies › Topsail".
    var folderBreadcrumb: String { Self.breadcrumb(of: folder) }

    /// A folder as Finder names it, with its parent: "Movies › Topsail".
    static func breadcrumb(of folder: URL) -> String {
        let names = [folder.deletingLastPathComponent(), folder].map { FileManager.default.displayName(atPath: $0.path) }
        return names.joined(separator: " › ")
    }

    /// The folder as people say it: ~/Movies/Topsail.
    var folderDisplayPath: String {
        let home = Self.defaultFolder.deletingLastPathComponent().deletingLastPathComponent().path
        let path = folder.path
        return path.hasPrefix(home + "/") ? "~" + path.dropFirst(home.count) : path
    }

    /// Asks for a folder in Settings (the one window Topsail opens besides the island), and keeps
    /// a security-scoped bookmark so the sandboxed build may write there after relaunching.
    func chooseFolder(in window: NSWindow?) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = String(localized: "Choose")
        panel.message = String(localized: "Choose where Topsail saves your recordings.")
        panel.directoryURL = folder
        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            MainActor.assumeIsolated { self?.setFolder(url) }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    func resetFolder() {
        defaults.removeObject(forKey: Key.folderBookmark)
        folder = Self.defaultFolder
    }

    func showFolder() {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        withFolderAccess { NSWorkspace.shared.activateFileViewerSelecting([$0]) }
    }

    private func setFolder(_ url: URL) {
        if let bookmark = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil,
                                                relativeTo: nil) {
            defaults.set(bookmark, forKey: Key.folderBookmark)
        }
        folder = url
    }

    private func resolveBookmark() -> URL? {
        guard let data = defaults.data(forKey: Key.folderBookmark) else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil,
                                 bookmarkDataIsStale: &stale) else { return nil }
        if stale, let fresh = try? url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil,
                                                    relativeTo: nil) {
            defaults.set(fresh, forKey: Key.folderBookmark)
        }
        return url
    }

    /// Runs `body` with the folder open to Topsail: a chosen folder is security-scoped under the
    /// App Sandbox (and the call is harmless without it).
    @discardableResult
    func withFolderAccess<T>(_ body: (URL) throws -> T) rethrows -> T {
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        return try body(folder)
    }
}
