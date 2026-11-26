import AppKit
import Combine
import QuickLookThumbnailing
import UniformTypeIdentifiers

/// A file parked on the shelf.
struct ShelfItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let addedAt: Date

    var name: String { url.lastPathComponent }
}

/// Files dropped on the notch, kept at hand across apps and restarts until removed. Only
/// references are kept (bookmarks, security-scoped in the App Store build so access survives a
/// relaunch): the files stay where they are, and nothing leaves the Mac except by AirDrop.
@MainActor
final class ShelfStore: ObservableObject {
    static let limit = 50

    @Published private(set) var items: [ShelfItem] = []
    /// Quick Look thumbnails, as they arrive; the file's icon until then.
    @Published private(set) var thumbnails: [UUID: NSImage] = [:]

    private let defaults = UserDefaults.standard
    private static let bookmarksKey = "shelf.bookmarks"
    /// Files whose security scope this process opened (App Store build), closed on removal.
    private var accessed: Set<URL> = []

    init() {
        #if DEBUG
        if Continuity.isActive { return }  // continuity tests: fixture data only
        #endif
        restore()
    }

    /// Adds files (folders too), newest first. A file already on the shelf moves to the front.
    func add(_ urls: [URL]) {
        let fileURLs = urls.filter(\.isFileURL)
        guard !fileURLs.isEmpty else { return }
        for url in fileURLs.reversed() {
            items.removeAll { $0.url.standardizedFileURL == url.standardizedFileURL }
            let item = ShelfItem(id: UUID(), url: url, addedAt: Date())
            items.insert(item, at: 0)
            loadThumbnail(for: item)
        }
        if items.count > Self.limit {
            for dropped in items[Self.limit...] { forget(dropped) }
            items.removeLast(items.count - Self.limit)
        }
        save()
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        forget(item)
        save()
    }

    func clear() {
        items.forEach(forget)
        items = []
        save()
    }

    func open(_ item: ShelfItem) {
        NSWorkspace.shared.open(item.url)
    }

    func reveal(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    /// Puts the files on the clipboard, to paste in Finder or an app.
    func copy(_ items: [ShelfItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items.map { $0.url as NSURL })
    }

    /// Opens AirDrop's picker for the files.
    func airDrop(_ items: [ShelfItem]) {
        guard !items.isEmpty, let service = NSSharingService(named: .sendViaAirDrop) else { return }
        let urls = items.map(\.url)
        if service.canPerform(withItems: urls) {
            service.perform(withItems: urls)
        }
    }

    /// A file deleted or moved away since it was shelved drops off.
    func pruneMissing() {
        let missing = items.filter { !FileManager.default.fileExists(atPath: $0.url.path) }
        guard !missing.isEmpty else { return }
        missing.forEach(forget)
        items.removeAll { item in missing.contains { $0.id == item.id } }
        save()
    }

    // MARK: Thumbnails

    private func loadThumbnail(for item: ShelfItem) {
        let request = QLThumbnailGenerator.Request(fileAt: item.url, size: CGSize(width: 64, height: 64),
                                                   scale: 2, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] representation, _ in
            guard let image = representation?.nsImage else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.thumbnails[item.id] = image }
            }
        }
    }

    /// The file's own icon, for before (or instead of) a thumbnail.
    static func icon(for url: URL) -> NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    // MARK: Persistence

    #if DIRECT
    private static let bookmarkOptions: URL.BookmarkCreationOptions = []
    private static let resolveOptions: URL.BookmarkResolutionOptions = [.withoutUI]
    #else
    private static let bookmarkOptions: URL.BookmarkCreationOptions = [.withSecurityScope]
    private static let resolveOptions: URL.BookmarkResolutionOptions = [.withSecurityScope, .withoutUI]
    #endif

    private func save() {
        #if DEBUG
        if Continuity.isActive { return }  // continuity tests: fixture data only
        #endif
        let bookmarks = items.compactMap {
            try? $0.url.bookmarkData(options: Self.bookmarkOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        defaults.set(bookmarks, forKey: Self.bookmarksKey)
    }

    private func restore() {
        guard let bookmarks = defaults.array(forKey: Self.bookmarksKey) as? [Data] else { return }
        for bookmark in bookmarks {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark, options: Self.resolveOptions,
                                     relativeTo: nil, bookmarkDataIsStale: &stale) else { continue }
            #if !DIRECT
            if url.startAccessingSecurityScopedResource() { accessed.insert(url) }
            #endif
            guard FileManager.default.fileExists(atPath: url.path) else { continue }
            let item = ShelfItem(id: UUID(), url: url, addedAt: Date())
            items.append(item)
            loadThumbnail(for: item)
        }
        save()
    }

    private func forget(_ item: ShelfItem) {
        thumbnails[item.id] = nil
        if accessed.remove(item.url) != nil {
            item.url.stopAccessingSecurityScopedResource()
        }
    }
}
