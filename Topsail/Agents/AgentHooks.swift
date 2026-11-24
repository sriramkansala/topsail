import Foundation

/// Adds (and removes) Topsail's hook in each agent's own settings file, so the agent tells Topsail
/// what it's doing and asks Topsail before risky commands:
/// - Claude Code: `~/.claude/settings.json` (`hooks`)
/// - Codex: `~/.codex/hooks.json` (`hooks`; Codex asks you to trust new hooks with /hooks)
/// - Cursor: `~/.cursor/hooks.json` (`version`, `hooks`)
/// - Antigravity: `~/.gemini/config/hooks.json` (a hook set named "topsail")
///
/// Every hook runs one script, `~/.topsail/topsail-hook <agent> <event>`, which posts the event to
/// Topsail and prints its answer; if Topsail isn't running or doesn't answer, it prints each agent's
/// "no objection", so the agent carries on exactly as it would without Topsail. A file is backed
/// up (`.topsail-backup`) the first time Topsail changes it. Only Topsail's own entries are touched.
enum AgentHooks {
    /// `~/.topsail`: the script and the socket. No spaces in the path, so no agent has to quote it.
    static var folder: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".topsail", isDirectory: true)
    }

    static var scriptURL: URL { folder.appendingPathComponent("topsail-hook") }

    /// The marker that tells Topsail's entries from the user's own.
    private static let marker = "/.topsail/topsail-hook"

    static func settingsFile(for agent: AgentKind) -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch agent {
        case .claude: return home.appendingPathComponent(".claude/settings.json")
        case .codex: return home.appendingPathComponent(".codex/hooks.json")
        case .cursor: return home.appendingPathComponent(".cursor/hooks.json")
        case .antigravity: return home.appendingPathComponent(".gemini/config/hooks.json")
        }
    }

    /// The agent seems installed: its settings folder exists.
    static func isInstalled(_ agent: AgentKind) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let folder: String
        switch agent {
        case .claude: folder = ".claude"
        case .codex: folder = ".codex"
        case .cursor: folder = ".cursor"
        case .antigravity: folder = ".gemini"
        }
        return FileManager.default.fileExists(atPath: home.appendingPathComponent(folder).path)
    }

    static func isConnected(_ agent: AgentKind) -> Bool {
        guard let data = try? Data(contentsOf: settingsFile(for: agent)),
              let text = String(data: data, encoding: .utf8) else { return false }
        return text.contains(marker)
    }

    /// Adds Topsail's hooks; `waitSeconds` is how long a permission hook may wait for an answer.
    static func connect(_ agent: AgentKind, waitSeconds: Int) throws {
        try writeScript()
        try edit(settingsFile(for: agent)) { root in
            removeTopsail(from: &root, agent: agent)
            addTopsail(to: &root, agent: agent, waitSeconds: waitSeconds)
        }
    }

    static func disconnect(_ agent: AgentKind) throws {
        let file = settingsFile(for: agent)
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        try edit(file) { root in removeTopsail(from: &root, agent: agent) }
    }

    /// Keeps the script current (it may have changed with an update).
    static func refreshScript() {
        guard AgentKind.allCases.contains(where: isConnected) else { return }
        try? writeScript()
    }

    // MARK: The script

    private static let script = """
    #!/bin/sh
    # Topsail's hook for AI coding agents (https://github.com/sriramkansala/topsail).
    # Usage: topsail-hook <agent> <event>, with the agent's event JSON on stdin.
    # Hands the event to Topsail in the notch and prints Topsail's answer. If Topsail isn't running or
    # doesn't answer, it prints the agent's "no objection", so the agent carries on as usual.
    SOCK="$HOME/.topsail/agents.sock"

    no_objection() {
      case "$1:$2" in
        cursor:before*) printf '%s\\n' '{"continue":true,"permission":"allow"}' ;;
        cursor:*) printf '%s\\n' '{}' ;;
        antigravity:PreToolUse) printf '%s\\n' '{"decision":"allow"}' ;;
        antigravity:*) printf '%s\\n' '{}' ;;
      esac
      exit 0
    }

    [ -S "$SOCK" ] || no_objection "$1" "$2"
    OUT=$(/usr/bin/curl -q -sf --noproxy '*' --max-time 600 --unix-socket "$SOCK" -H 'Content-Type: application/json' \\
      -H 'Expect:' --data-binary @- "http://topsail/$1/$2") || no_objection "$1" "$2"
    [ -n "$OUT" ] || no_objection "$1" "$2"
    printf '%s\\n' "$OUT"
    """

    private static func writeScript() throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try Data(script.utf8).write(to: scriptURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
    }

    private static func command(_ agent: AgentKind, _ event: String) -> String {
        "\(scriptURL.path) \(agent.rawValue) \(event)"
    }

    // MARK: Editing the agents' files

    /// Events Topsail listens to, per agent, and which of them may wait for the user.
    private static func events(for agent: AgentKind) -> [(name: String, matcher: String?, waits: Bool)] {
        switch agent {
        case .claude:
            return [("SessionStart", nil, false), ("UserPromptSubmit", nil, false), ("PreToolUse", "", false),
                    ("PostToolUse", "", false), ("PermissionRequest", "", true), ("Notification", "", false),
                    ("Stop", nil, false), ("SessionEnd", nil, false)]
        case .codex:
            return [("SessionStart", nil, false), ("UserPromptSubmit", nil, false), ("PreToolUse", "", false),
                    ("PostToolUse", "", false), ("PermissionRequest", "", true), ("Stop", nil, false),
                    ("SessionEnd", nil, false)]
        case .cursor:
            return [("beforeShellExecution", nil, true), ("afterShellExecution", nil, false),
                    ("afterFileEdit", nil, false), ("stop", nil, false)]
        case .antigravity:
            return [("SessionStart", nil, false), ("PreInvocation", nil, false), ("PreToolUse", "", true),
                    ("PostToolUse", "", false), ("Stop", nil, false)]
        }
    }

    private static func addTopsail(to root: inout [String: Any], agent: AgentKind, waitSeconds: Int) {
        let waitTimeout = waitSeconds + 30
        switch agent {
        case .claude, .codex:
            var hooks = root["hooks"] as? [String: Any] ?? [:]
            for event in events(for: agent) {
                var group: [String: Any] = ["hooks": [["type": "command", "command": command(agent, event.name),
                                                       "timeout": event.waits ? waitTimeout : 10]]]
                if let matcher = event.matcher { group["matcher"] = matcher }
                hooks[event.name] = (hooks[event.name] as? [Any] ?? []) + [group]
            }
            root["hooks"] = hooks
        case .cursor:
            root["version"] = root["version"] ?? 1
            var hooks = root["hooks"] as? [String: Any] ?? [:]
            for event in events(for: agent) {
                let entry: [String: Any] = ["command": command(agent, event.name),
                                            "timeout": event.waits ? waitTimeout : 10]
                hooks[event.name] = (hooks[event.name] as? [Any] ?? []) + [entry]
            }
            root["hooks"] = hooks
        case .antigravity:
            var set: [String: Any] = [:]
            for event in events(for: agent) {
                let handler: [String: Any] = ["type": "command", "command": command(agent, event.name),
                                              "timeout": event.waits ? waitTimeout : 10]
                if let matcher = event.matcher {
                    set[event.name] = [["matcher": matcher, "hooks": [handler]]]
                } else {
                    set[event.name] = [handler]
                }
            }
            root["topsail"] = set
        }
    }

    private static func removeTopsail(from root: inout [String: Any], agent: AgentKind) {
        switch agent {
        case .claude, .codex, .cursor:
            guard var hooks = root["hooks"] as? [String: Any] else { return }
            for (event, value) in hooks {
                guard let entries = value as? [Any] else { continue }
                let kept = entries.filter { !mentionsTopsail($0) }
                if kept.isEmpty { hooks[event] = nil } else { hooks[event] = kept }
            }
            if hooks.isEmpty, agent != .cursor { root["hooks"] = nil } else { root["hooks"] = hooks }
        case .antigravity:
            root["topsail"] = nil
        }
    }

    private static func mentionsTopsail(_ value: Any) -> Bool {
        guard let data = try? JSONSerialization.data(withJSONObject: value),
              let text = String(data: data, encoding: .utf8) else { return false }
        return text.replacingOccurrences(of: "\\/", with: "/").contains(marker)
    }

    /// Reads a JSON object file (or starts an empty one), changes it, and writes it back, keeping
    /// a one-time backup of the original.
    private static func edit(_ file: URL, _ change: (inout [String: Any]) -> Void) throws {
        let manager = FileManager.default
        var root: [String: Any] = [:]
        if let data = try? Data(contentsOf: file), !data.isEmpty {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CocoaError(.fileReadCorruptFile, userInfo: [NSFilePathErrorKey: file.path])
            }
            root = object
            let backup = file.appendingPathExtension("topsail-backup")
            if !manager.fileExists(atPath: backup.path) {
                try? manager.copyItem(at: file, to: backup)
            }
        }
        change(&root)
        try manager.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys,
                                                                             .withoutEscapingSlashes])
        try data.write(to: file, options: .atomic)
    }
}
