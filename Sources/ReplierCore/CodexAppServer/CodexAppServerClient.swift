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
            transport = try ProcessTransport(executableURL: executableURL, arguments: ["app-server"])
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
            "developerInstructions": .string(prompt.system)
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
