import Combine
import Foundation

/// Follows AI coding agents (Claude Code, Codex, Cursor, Antigravity) through the hooks Clove
/// installs in their settings (`AgentHooks`): what each session is doing, when it finishes, and
/// the commands it asks to run. Routine read-only commands can be approved automatically; the
/// rest wait for Approve or Deny in the notch, and if nobody answers in time the agent's own
/// prompt takes over. Direct download only: the App Store build can't write other apps' settings.
@MainActor
final class AgentHub: ObservableObject {
    @Published private(set) var sessions: [AgentSession] = []
    @Published private(set) var approvals: [AgentApproval] = []
    /// Why the hooks' socket couldn't open, if it couldn't.
    @Published private(set) var serverError: String?

    /// An approval to show in the notch.
    var onApproval: ((AgentApproval) -> Void)?
    /// An approval answered or expired elsewhere (the Agents page, the timer): the notch drops it.
    var onApprovalClosed: ((AgentApproval) -> Void)?
    /// A session finished its turn.
    var onFinished: ((AgentSession) -> Void)?

    var autoApproveReadOnly = true
    var askInNotch = true
    var waitSeconds: TimeInterval = 60

    static var socketPath: String { AgentHooks.folder.appendingPathComponent("agents.sock").path }

    #if DIRECT
    private var server: AgentServer?
    #endif
    private var waiting: [UUID: CheckedContinuation<Bool?, Never>] = [:]
    private var sweepTimer: Timer?

    var isWorking: Bool { sessions.contains(where: \.isWorking) }
    /// The agent doing something right now, for beside the notch.
    var workingAgent: AgentKind? { sessions.last(where: \.isWorking)?.agent }

    func isPending(_ approval: AgentApproval) -> Bool {
        approvals.contains { $0.id == approval.id }
    }

    func start() {
        #if DIRECT
        guard server == nil else { return }
        let server = AgentServer(socketPath: Self.socketPath) { [weak self] agent, event, body in
            await self?.handle(agent: agent, event: event, body: body) ?? Data()
        }
        do {
            try server.start()
            self.server = server
            serverError = nil
            AgentHooks.refreshScript()
        } catch {
            serverError = error.localizedDescription
        }
        let sweep = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sweep() }
        }
        RunLoop.main.add(sweep, forMode: .common)
        sweepTimer = sweep
        #endif
    }

    func stop() {
        #if DIRECT
        server?.stop()
        server = nil
        #endif
        sweepTimer?.invalidate()
        sweepTimer = nil
        for approval in approvals { resolve(approval.id, nil) }
        sessions = []
    }

    /// Approve or Deny, from the notch or the Agents page; nil leaves it to the agent's own prompt.
    /// A request that can't be shown whole is never approved here.
    func answer(_ approval: AgentApproval, approve: Bool?) {
        resolve(approval.id, approve == true && !approval.isReviewable ? nil : approve)
    }

    /// Forgets a finished session (the Agents page's ✕).
    func dismiss(_ session: AgentSession) {
        sessions.removeAll { $0.id == session.id }
    }

    // MARK: Events

    /// One hook event: updates the session and, for a permission event, answers it.
    func handle(agent: String, event: String, body: Data) async -> Data {
        guard let kind = AgentKind(rawValue: agent),
              let json = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else { return Data() }
        let info = EventInfo(kind: kind, json: json)

        switch (kind, event) {
        case (_, "SessionStart"), (.cursor, "sessionStart"):
            update(info, .waiting(nil))
        case (_, "UserPromptSubmit"), (.antigravity, "PreInvocation"):
            update(info, .working(String(localized: "Thinking")))
        case (.claude, "PreToolUse"), (.codex, "PreToolUse"):
            update(info, .working(info.activity))
        case (_, "PostToolUse"), (.cursor, "afterShellExecution"):
            touch(info)
        case (.cursor, "afterFileEdit"):
            update(info, .working(info.activity))
        case (.claude, "Notification"):
            update(info, .waiting(json["message"] as? String))
        case (.claude, "PermissionRequest"), (.codex, "PermissionRequest"):
            return await decide(info)
        case (.cursor, "beforeShellExecution"):
            update(info, .working(info.activity))
            return await decide(info)
        case (.antigravity, "PreToolUse"):
            update(info, .working(info.activity))
            return info.toolName == "run_command" ? await decide(info) : Data()
        case (_, "Stop"), (.cursor, "stop"):
            finish(info)
        case (_, "SessionEnd"), (.cursor, "sessionEnd"):
            sessions.removeAll { $0.id == info.sessionKey }
        default:
            break
        }
        return Data()
    }

    /// A permission event: auto-approved if it's a read-only command and that's on, else asked in
    /// the notch; no answer (or asking off) leaves it to the agent.
    private func decide(_ info: EventInfo) async -> Data {
        if autoApproveReadOnly, info.isPlainShell, let command = info.command, Self.isReadOnly(command) {
            return Self.allow(info.kind)
        }
        guard askInNotch else { return Data() }
        let approval = AgentApproval(id: UUID(), agent: info.kind, project: info.project, verb: info.verb,
                                     detail: info.detail, expires: Date().addingTimeInterval(waitSeconds))
        update(info, .waiting(String(localized: "Needs your OK")))
        let answer = await withCheckedContinuation { continuation in
            waiting[approval.id] = continuation
            approvals.append(approval)
            onApproval?(approval)
            DispatchQueue.main.asyncAfter(deadline: .now() + waitSeconds) { [weak self] in
                MainActor.assumeIsolated { self?.resolve(approval.id, nil) }
            }
        }
        update(info, .working(nil))
        guard let answer else { return Data() }
        return answer ? Self.allow(info.kind) : Self.deny(info.kind)
    }

    private func resolve(_ id: UUID, _ answer: Bool?) {
        guard let continuation = waiting.removeValue(forKey: id) else { return }
        if let approval = approvals.first(where: { $0.id == id }) {
            approvals.removeAll { $0.id == id }
            onApprovalClosed?(approval)
        }
        continuation.resume(returning: answer)
    }

    private func update(_ info: EventInfo, _ status: AgentSession.Status) {
        let now = Date()
        if let index = sessions.firstIndex(where: { $0.id == info.sessionKey }) {
            if sessions[index].status != status { sessions[index].since = now }
            sessions[index].status = status
            if !info.project.isEmpty { sessions[index].project = info.project }
        } else {
            sessions.append(AgentSession(id: info.sessionKey, agent: info.kind, project: info.project,
                                         status: status, since: now, startedAt: now))
        }
    }

    /// An event that changes nothing visible but shows the session is alive.
    private func touch(_ info: EventInfo) {
        if !sessions.contains(where: { $0.id == info.sessionKey }) { update(info, .working(nil)) }
    }

    private func finish(_ info: EventInfo) {
        let wasWorking = sessions.first { $0.id == info.sessionKey }?.isWorking ?? true
        update(info, .finished)
        if wasWorking, let session = sessions.first(where: { $0.id == info.sessionKey }) {
            onFinished?(session)
        }
    }

    /// Finished sessions leave after half an hour; ones silent for two hours are gone.
    private func sweep() {
        let now = Date()
        sessions.removeAll { session in
            let age = now.timeIntervalSince(session.since)
            return (session.status == .finished && age > 30 * 60) || age > 2 * 3600
        }
    }

    // MARK: Answers, per agent

    static func allow(_ kind: AgentKind) -> Data {
        switch kind {
        case .claude, .codex:
            return json(["hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": ["behavior": "allow"]]])
        case .cursor:
            return json(["continue": true, "permission": "allow"])
        case .antigravity:
            return json(["decision": "auto_approve"])
        }
    }

    static func deny(_ kind: AgentKind) -> Data {
        let message = "Denied in Clove"
        switch kind {
        case .claude, .codex:
            return json(["hookSpecificOutput": ["hookEventName": "PermissionRequest",
                                                "decision": ["behavior": "deny", "message": message]]])
        case .cursor:
            return json(["continue": true, "permission": "deny", "user_message": message,
                         "agent_message": "The user denied this command in Clove."])
        case .antigravity:
            return json(["decision": "deny", "reason": message])
        }
    }

    private static func json(_ object: [String: Any]) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data()
    }

    /// Commands that only look, at ordinary files in the project: approved without asking when
    /// "Approve read-only commands" is on. Anything unsure is not read-only, and is asked about.
    /// Not here: chaining, pipes, redirects, substitution, globs and quoting (which can hide any
    /// of those); paths outside the project; hidden files and names that look like secrets; and
    /// options that write files, run programs or read hidden files.
    static func isReadOnly(_ command: String) -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespaces)
        let plain = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -_./=:,+@%")
        guard !trimmed.isEmpty, trimmed.count <= 200,
              trimmed.unicodeScalars.allSatisfy(plain.contains) else { return false }
        let words = trimmed.split(separator: " ").map(String.init)
        guard let first = words.first else { return false }
        let arguments = Array(words.dropFirst())
        guard arguments.allSatisfy(isOrdinaryArgument) else { return false }

        // Options allowed to take any value would be a way around all this, so each command lists
        // the few it may have; anything else is asked about.
        let options = arguments.filter { $0.hasPrefix("-") }
        func only(_ allowed: Set<String>) -> Bool { options.allSatisfy(allowed.contains) }
        switch first {
        case "pwd", "whoami": return arguments.isEmpty
        case "ls": return only(["-l", "-a", "-la", "-al", "-lh", "-lah", "-1", "-R", "-t", "-lt"])
        case "cat": return !arguments.isEmpty && only(["-n"])
        case "head", "tail": return !arguments.isEmpty && options.allSatisfy { $0 == "-n" || Int($0.dropFirst()) != nil }
        case "wc": return only(["-l", "-w", "-c"])
        case "which", "echo": return options.isEmpty
        case "grep": return only(["-n", "-i", "-c", "-l", "-w", "-in", "-ni", "-E"])
        case "rg": return only(["-n", "-i", "-c", "-l", "-w"])
        case "tree": return options.isEmpty
        case "git":
            guard let sub = arguments.first, !sub.hasPrefix("-") else { return false }
            switch sub {
            case "status": return only(["-s", "--short", "-b"])
            case "diff": return only(["--stat", "--cached", "--staged", "--name-only"])
            case "log": return options.allSatisfy { ["--oneline", "--stat", "--graph"].contains($0) || Int($0.dropFirst()) != nil }
            case "branch": return arguments.count == 1 || (arguments.count == 2 && ["-a", "-r", "-v"].contains(arguments[1]))
            default: return false
            }
        default: return false
        }
    }

    /// Inside the project, not hidden, and not named like a secret.
    private static func isOrdinaryArgument(_ argument: String) -> Bool {
        if argument.hasPrefix("/") || argument.contains("=/") || argument.contains(":") { return false }
        let parts = argument.split(separator: "/").map { $0.lowercased() }
        for part in parts where part != "." {
            if part.hasPrefix(".") { return false }  // hidden files, and ".."
            if ["secret", "credential", "password", "passwd", "token", "id_rsa", "id_ed25519", "keychain"]
                .contains(where: part.contains) { return false }
            if [".pem", ".key", ".p12", ".pfx", ".env", ".keystore", ".mobileprovision"].contains(where: part.hasSuffix) {
                return false
            }
        }
        return true
    }
}

/// What a hook event says, read the same way for every agent.
private struct EventInfo {
    let kind: AgentKind
    let sessionID: String
    let project: String
    let toolName: String?
    let command: String?
    let filePath: String?
    /// Everything the tool was given, for showing before it's approved.
    let input: [String: Any]
    /// A shell command and nothing else that changes how it runs (no sandbox off, say), so the
    /// command alone is the whole story.
    let isPlainShell: Bool

    var sessionKey: String { "\(kind.rawValue):\(sessionID)" }

    init(kind: AgentKind, json: [String: Any]) {
        self.kind = kind
        let input = json["tool_input"] as? [String: Any]
        self.input = input ?? ((json["toolCall"] as? [String: Any])?["args"] as? [String: Any]) ?? [:]
        switch kind {
        case .claude, .codex:
            sessionID = json["session_id"] as? String ?? "default"
            project = Self.folderName(json["cwd"] as? String)
            toolName = json["tool_name"] as? String
            command = input?["command"] as? String
            filePath = input?["file_path"] as? String ?? input?["path"] as? String
            isPlainShell = toolName == "Bash" && command != nil
                && Set((input ?? [:]).keys).isSubset(of: ["command", "description", "timeout"])
        case .cursor:
            sessionID = json["conversation_id"] as? String ?? "default"
            project = Self.folderName((json["workspace_roots"] as? [String])?.first ?? json["cwd"] as? String)
            toolName = json["hook_event_name"] as? String
            command = json["command"] as? String
            filePath = json["file_path"] as? String
            isPlainShell = command != nil
        case .antigravity:
            sessionID = json["conversationId"] as? String ?? "default"
            project = Self.folderName((json["workspacePaths"] as? [String])?.first)
            let call = json["toolCall"] as? [String: Any]
            let args = call?["args"] as? [String: Any]
            toolName = call?["name"] as? String
            command = args?["CommandLine"] as? String ?? args?["command"] as? String
            filePath = args?["TargetFile"] as? String ?? args?["AbsolutePath"] as? String ?? args?["file_path"] as? String
            isPlainShell = toolName == "run_command" && Set((args ?? [:]).keys).isSubset(of: ["CommandLine"])
        }
    }

    private static func folderName(_ path: String?) -> String {
        guard let path, !path.isEmpty else { return "" }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private var fileName: String? { filePath.map { URL(fileURLWithPath: $0).lastPathComponent } }

    /// "Running npm test", "Editing Clove.swift", "Reading README.md"…
    var activity: String? {
        if let command { return String(localized: "Running \(Self.shorten(command))") }
        let tool = (toolName ?? "").lowercased()
        if tool.contains("edit") || tool.contains("write") || tool.contains("patch") || tool.contains("replace")
            || tool == "afterfileedit" {
            return fileName.map { String(localized: "Editing \($0)") } ?? String(localized: "Editing files")
        }
        if tool.contains("read") || tool.contains("view") { return fileName.map { String(localized: "Reading \($0)") } }
        if tool.contains("grep") || tool.contains("glob") || tool.contains("search") { return String(localized: "Searching") }
        if tool.contains("web") || tool.contains("browser") { return String(localized: "Browsing") }
        if tool == "task" || tool == "agent" { return String(localized: "Running a subagent") }
        return toolName
    }

    var verb: String {
        if command != nil { return String(localized: "run") }
        let tool = (toolName ?? "").lowercased()
        if tool.contains("edit") || tool.contains("write") || tool.contains("patch") { return String(localized: "edit") }
        return String(localized: "use \(toolName ?? "a tool")")
    }

    /// What it asks about, in full: the command, or the tool with everything it was given. Never
    /// a summary, because it is what gets approved.
    var detail: String {
        if isPlainShell, let command { return command }
        let name = toolName ?? ""
        guard !input.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: input, options: [.sortedKeys, .withoutEscapingSlashes]),
              let text = String(data: data, encoding: .utf8) else { return command ?? filePath ?? name }
        return name.isEmpty ? text : "\(name) \(text)"
    }

    static func shorten(_ command: String) -> String {
        let line = command.split(separator: "\n").first.map(String.init) ?? command
        return line.count > 60 ? String(line.prefix(59)) + "…" : line
    }
}
