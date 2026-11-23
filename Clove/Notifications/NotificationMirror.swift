import AppKit
import Combine
import SQLite3

/// Another app's notification, as the notch shows it.
struct MirroredNotification: Identifiable, Equatable {
    let id: Int64
    let bundleID: String
    let appName: String
    let title: String
    let body: String

    /// The app's icon, if it's installed.
    var icon: NSImage? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
    }

    func open() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}

/// Other apps' notifications, from the list Notification Center keeps (macOS has no API for
/// them). Needs Full Disk Access, so the direct download only. The list is opened read-only,
/// while the feature is on; nothing in it is kept, copied or sent, and only what arrives after
/// the feature is turned on, from the apps chosen in Settings, is shown.
@MainActor
final class NotificationMirror: ObservableObject {
    enum Access: Equatable {
        case unknown
        /// Full Disk Access is missing.
        case denied
        case granted
        /// Readable, but not laid out as Clove knows it (a new macOS, perhaps).
        case unsupported
    }

    @Published private(set) var access: Access = .unknown
    var onNotification: ((MirroredNotification) -> Void)?
    /// Lower-case bundle identifiers to show.
    var apps: Set<String> = []

    private let database: String
    private var timer: Timer?
    private var lastRecord: Int64?

    /// Apps offered in Settings, if they're installed. (Identifiers are matched ignoring case: the
    /// list stores some in lower case.)
    static let knownApps = ["com.apple.MobileSMS", "com.apple.mail", "com.tinyspeck.slackmacgap", "com.hnc.Discord",
                            "com.burbn.instagram", "net.whatsapp.WhatsApp", "ru.keepcoder.Telegram",
                            "com.microsoft.teams2", "com.apple.FaceTime"]

    nonisolated static let defaultDatabase = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Group Containers/group.com.apple.usernoted/db2/db").path

    init(database: String = NotificationMirror.defaultDatabase) {
        self.database = database
    }

    func start() {
        guard timer == nil else { return }
        lastRecord = nil
        poll()
        let timer = Timer(timeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        lastRecord = nil
        access = .unknown
    }

    /// Shows what arrived since the last look. The first look only notes where the list ends, so
    /// turning the feature on doesn't replay old notifications.
    func poll() {
        #if DIRECT
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        guard sqlite3_open_v2(database, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            set(.denied)
            return
        }
        sqlite3_busy_timeout(db, 200)

        guard let last = lastRecord else {
            switch latestRecord(in: db) {
            case .success(let latest):
                lastRecord = latest
                set(.granted)
            case .failure(let error):
                set(error)
            }
            return
        }

        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        let query = """
            SELECT r.rec_id, a.identifier, r.data FROM record r JOIN app a ON a.app_id = r.app_id
            WHERE r.rec_id > ? ORDER BY r.rec_id LIMIT 20
            """
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            set(.unsupported)
            return
        }
        sqlite3_bind_int64(statement, 1, last)
        while sqlite3_step(statement) == SQLITE_ROW {
            let record = sqlite3_column_int64(statement, 0)
            lastRecord = record
            guard let identifier = sqlite3_column_text(statement, 1).map({ String(cString: $0) }),
                  apps.contains(identifier.lowercased()),
                  let bytes = sqlite3_column_blob(statement, 2) else { continue }
            let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 2)))
            if let notification = Self.read(record: record, identifier: identifier, data: data) {
                onNotification?(notification)
            }
        }
        set(.granted)
        #endif
    }

    private func set(_ value: Access) {
        if access != value { access = value }
    }

    #if DIRECT
    private enum ReadResult {
        case success(Int64)
        case failure(Access)
    }

    private func latestRecord(in db: OpaquePointer) -> ReadResult {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        let prepared = sqlite3_prepare_v2(db, "SELECT COALESCE(MAX(rec_id), 0) FROM record", -1, &statement, nil)
        guard prepared == SQLITE_OK else {
            // Opening is lazy: without Full Disk Access it's the first read that's refused.
            let refused = [SQLITE_CANTOPEN, SQLITE_AUTH, SQLITE_PERM, SQLITE_IOERR].contains(prepared & 0xff)
            return .failure(refused ? .denied : .unsupported)
        }
        guard sqlite3_step(statement) == SQLITE_ROW else { return .failure(.denied) }
        return .success(sqlite3_column_int64(statement, 0))
    }
    #endif

    /// A record's property list: `req` holds the title, subtitle and body.
    static func read(record: Int64, identifier: String, data: Data) -> MirroredNotification? {
        guard let plist = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
              let request = plist["req"] as? [String: Any] else { return nil }
        let title = request["titl"] as? String ?? ""
        let subtitle = request["subt"] as? String ?? ""
        let body = request["body"] as? String ?? ""
        guard !title.isEmpty || !body.isEmpty else { return nil }
        let bundleID = knownApps.first { $0.lowercased() == identifier.lowercased() } ?? identifier
        return MirroredNotification(id: record, bundleID: bundleID, appName: name(of: bundleID),
                                    title: title.isEmpty ? subtitle : title,
                                    body: [title.isEmpty ? "" : subtitle, body].filter { !$0.isEmpty }.joined(separator: " · "))
    }

    static func name(of bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return bundleID }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }

    /// The offered apps that are on this Mac.
    static var installedApps: [String] {
        knownApps.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
    }
}
