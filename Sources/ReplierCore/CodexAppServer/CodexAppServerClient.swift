import Foundation

/// Speaks the `codex app-server` JSON-RPC protocol over stdio: one prompt in, streamed
/// agent-message text out. Never approves execution of commands or file changes.
public actor CodexAppServerClient {
    private let executableURL: URL?
    private let injectedTransport: (any JSONRPCTransport)?

    private var connection: JSONRPCConnection?
    private var notificationTask: Task<Void, Never>?
    private var activeTurn: ActiveTurn?

    private struct ActiveTurn {
        let threadId: String
        let turnId: String
        let continuation: AsyncThrowingStream<String, Error>.Continuation
    }

    public init(executableURL: URL) {
        self.executableURL = executableURL
        self.injectedTransport = nil
    }

    /// Test-only entry point: bypasses process spawning entirely.
    internal init(transport: any JSONRPCTransport) {
        self.executableURL = nil
        self.injectedTransport = transport
    }

    /// Flags applied to every `codex app-server` spawn, independent of which servers the user
    /// has configured. All verified accepted by codex 0.147.0 (an unrecognized `--disable` name
    /// or config value exits the process immediately, so nothing here is speculative).
    static let baseArguments: [String] = [
        // Documents intent, but is a no-op against a populated `mcp_servers` table: codex's `-c`
        // overrides deep-merge into the base config rather than replacing it, so merging `{}`
        // (no keys) changes nothing. Superseded by the per-server `enabled=false` overrides
        // computed in `mcpServerDisableArguments`, which is what actually stops each server.
        "-c", "mcp_servers={}",
        // Removes the web_search tool definition from the turn's tool list.
        "-c", "web_search=\"disabled\"",
        // Opts out of codex's own ~/.codex/history.jsonl log (distinct from, and in addition to,
        // the per-thread `ephemeral` flag set in draftReplies below).
        "-c", "history.persistence=\"none\"",
        // Skips lifecycle hook (SessionStart/UserPromptSubmit/Stop/...) lookup and execution.
        "--disable", "hooks",
        // Skips loading/injecting every configured plugin's tool defs and instructions;
        // measured as the single largest contributor to turn latency in this set.
        "--disable", "plugins",
        // Skips scanning ~/.codex/skills to build the skill-discovery tool.
        "--disable", "skill_search",
        // Removes the shell/exec tool definition (the client declines every exec approval
        // anyway; this stops it from being offered to the model in the first place).
        "--disable", "shell_tool",
        // Removes the underlying unified-exec mechanism backing shell/apply-patch tool calls.
        "--disable", "unified_exec",
        // Text-only turns need no extra tool surfaces; each adds tool definitions to the turn.
        "--disable", "apps",
        "--disable", "browser_use",
        "--disable", "browser_use_external",
        "--disable", "in_app_browser",
        "--disable", "computer_use",
    ]

    /// `-c mcp_servers={}` doesn't clear a non-empty `mcp_servers` table (see `baseArguments`),
    /// so each server configured in `$CODEX_HOME/config.toml` must be disabled by name. This is
    /// the only override verified to actually stop connection attempts (including OAuth token
    /// refreshes for remote servers and process spawns for local stdio servers).
    static func mcpServerDisableArguments(codexHome: URL) -> [String] {
        configuredMCPServerNames(codexHome: codexHome).flatMap { name in
            ["-c", "mcp_servers.\(name).enabled=false"]
        }
    }

    /// Reads (never writes) `$CODEX_HOME/config.toml` to discover configured MCP server names.
    static func configuredMCPServerNames(codexHome: URL) -> [String] {
        let configURL = codexHome.appendingPathComponent("config.toml")
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else { return [] }
        return mcpServerNames(fromConfigTOML: text)
    }

    /// Extracts top-level `[mcp_servers.<name>]` table names from raw TOML text: matches bare
    /// (unquoted) keys only and anchors the closing `]` so nested tables like
    /// `[mcp_servers.linear.tools.save_issue]` aren't mistaken for a server named "linear.tools".
    /// Quoted server names (`[mcp_servers."my server"]`) are intentionally skipped: codex's `-c`
    /// dotted-path parser doesn't understand quoted segments and hard-fails startup if given one
    /// (verified), so silently omitting them is safer than emitting a flag that could break app
    /// launch for an edge case not present in typical configs.
    static func mcpServerNames(fromConfigTOML text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"^\[mcp_servers\.([A-Za-z0-9_-]+)\]\s*$"#)
        else { return [] }
        var names: [String] = []
        text.enumerateLines { line, _ in
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard
                let match = regex.firstMatch(in: line, range: range),
                let nameRange = Range(match.range(at: 1), in: line)
            else { return }
            names.append(String(line[nameRange]))
        }
        return names
    }

    /// Mirrors codex's own `$CODEX_HOME` resolution (env var, falling back to `~/.codex`) so the
    /// config file we read to discover MCP server names matches what the spawned process loads.
    static func resolveCodexHome() -> URL {
        if let override = ProcessInfo.processInfo.environment["CODEX_HOME"], !override.isEmpty {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    }

    /// Probes common install locations, then falls back to a login-shell `which codex`
    /// lookup (GUI apps do not inherit a full interactive-shell `PATH`, e.g. mise shims).
    public static func locateExecutable() -> URL? {
        let candidates = ["/opt/homebrew/bin/codex", "/usr/local/bin/codex"]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-lc", "which codex"]
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !output.isEmpty,
            FileManager.default.isExecutableFile(atPath: output)
        else { return nil }
        return URL(fileURLWithPath: output)
    }

    /// Spawns `codex app-server` (stdio transport is the default; no `--listen` flag needed)
    /// and performs the `initialize` handshake, followed by the required `initialized`
    /// notification (see `ClientNotification.json`).
    public func start() async throws {
        guard connection == nil else { return }

        let transport: any JSONRPCTransport
        if let injectedTransport {
            transport = injectedTransport
        } else {
            guard
                let executableURL,
                FileManager.default.isExecutableFile(atPath: executableURL.path)
            else {
                throw CodexClientError.codexExecutableNotFound
            }
            // replier only runs one text-only turn per launch; strip MCP/hooks/plugins/skills/
            // tool-definition overhead not needed for that (see baseArguments and
            // mcpServerDisableArguments for the rationale behind each flag).
            let codexHome = Self.resolveCodexHome()
            let arguments =
                ["app-server"] + Self.baseArguments + Self.mcpServerDisableArguments(codexHome: codexHome)
            transport = try ProcessTransport(executableURL: executableURL, arguments: arguments)
        }

        let connection = JSONRPCConnection(transport: transport)
        self.connection = connection
        await connection.setRequestHandler { [weak self] method, params in
            await self?.handleServerRequest(method: method, params: params)
                ?? .failure(JSONRPCError(code: -32001, message: "client is shutting down"))
        }
        await connection.start()
        notificationTask = Task { [weak self] in
            await self?.consumeNotifications()
        }

        let initializeParams: JSONValue = .object([
            "clientInfo": .object([
                "name": .string("replier"),
                "version": .string(Self.clientVersion),
            ])
        ])
        _ = try await connection.requestRaw(method: CodexMethod.initialize, params: initializeParams)
        try await connection.notify(method: CodexMethod.initialized, params: nil)
    }

    public func accountStatus() async throws -> CodexAccountStatus {
        guard let connection else { throw CodexClientError.notStarted }
        let response = try await connection.requestRaw(method: CodexMethod.accountRead, params: .object([:]))
        return CodexAccountStatusMapper.map(response)
    }

    /// One-shot: starts a fresh thread, runs one turn with `prompt`, and streams agent-message
    /// text deltas as they arrive. `prompt.system` is passed as `ThreadStartParams.developerInstructions`
    /// (`TurnStartParams` itself has no system/developer-instructions field), and `prompt.user`
    /// becomes the turn's text input verbatim. `model` and `effort` map directly to
    /// `TurnStartParams.model` / `TurnStartParams.effort` (see
    /// `docs/reference/app-server-schema/v2/TurnStartParams.json`), which override the model
    /// and reasoning effort for this turn; omitted when `nil` so the server falls back to its
    /// configured defaults.
    public func draftReplies(
        _ prompt: Prompt,
        model: String? = nil,
        effort: String? = nil
    ) async throws -> AsyncThrowingStream<String, Error> {
        guard let connection else { throw CodexClientError.notStarted }
        guard activeTurn == nil else {
            throw CodexClientError.turnFailed("a turn is already in progress")
        }

        let threadParams: JSONValue = .object([
            "developerInstructions": .string(prompt.system),
            // Keeps this thread's prompt/reply out of ~/.codex/sessions rollout files entirely
            // (verified: more effective for this than the `history.persistence="none"` spawn
            // flag, which only covers the separate history.jsonl log).
            "ephemeral": .bool(true),
        ])
        let threadResponse = try await connection.requestRaw(method: CodexMethod.threadStart, params: threadParams)
        guard case .string(let threadId)? = threadResponse["thread"]?["id"] else {
            throw CodexClientError.turnFailed("thread/start response missing thread id")
        }

        var turnParamsFields: [String: JSONValue] = [
            "threadId": .string(threadId),
            "input": .array([
                .object(["type": .string("text"), "text": .string(prompt.user)])
            ]),
        ]
        if let model { turnParamsFields["model"] = .string(model) }
        if let effort { turnParamsFields["effort"] = .string(effort) }
        let turnParams: JSONValue = .object(turnParamsFields)
        let turnResponse = try await connection.requestRaw(method: CodexMethod.turnStart, params: turnParams)
        guard case .string(let turnId)? = turnResponse["turn"]?["id"] else {
            throw CodexClientError.turnFailed("turn/start response missing turn id")
        }

        let (stream, continuation) = AsyncThrowingStream<String, Error>.makeStream(of: String.self)
        activeTurn = ActiveTurn(threadId: threadId, turnId: turnId, continuation: continuation)
        return stream
    }

    public func shutdown() async {
        if let activeTurn {
            activeTurn.continuation.finish(throwing: CodexClientError.turnFailed("client shut down"))
            self.activeTurn = nil
        }
        await connection?.close()
        notificationTask?.cancel()
        notificationTask = nil
        connection = nil
    }

    private func consumeNotifications() async {
        guard let connection else { return }
        for await notification in connection.notifications {
            handle(notification)
        }
    }

    private func handle(_ notification: JSONRPCIncomingNotification) {
        switch notification.method {
        case CodexMethod.agentMessageDelta:
            guard
                let delta = CodexNotificationParser.agentMessageDelta(from: notification.params),
                let activeTurn,
                delta.turnId == activeTurn.turnId
            else { return }
            activeTurn.continuation.yield(delta.delta)

        case CodexMethod.turnCompleted:
            guard
                let completed = CodexNotificationParser.turnCompleted(from: notification.params),
                let activeTurn,
                completed.turnId == activeTurn.turnId
            else { return }
            activeTurn.continuation.finish()
            self.activeTurn = nil

        case CodexMethod.error:
            guard
                let errorInfo = CodexNotificationParser.turnError(from: notification.params),
                let activeTurn,
                errorInfo.turnId == activeTurn.turnId
            else { return }
            activeTurn.continuation.finish(throwing: CodexClientError.turnFailed(errorInfo.message))
            self.activeTurn = nil

        default:
            break
        }
    }

    /// Rejects every server-initiated request: we never execute commands or apply patches,
    /// and don't support the other experimental server-request methods either.
    private func handleServerRequest(method: String, params: JSONValue?) async -> Result<JSONValue, JSONRPCError> {
        if let response = CodexApprovalResponder.response(for: method) {
            return response
        }
        return .failure(JSONRPCError(code: -32001, message: "replier declines unsupported request: \(method)"))
    }

    private static let clientVersion = "0.1.0"
}
