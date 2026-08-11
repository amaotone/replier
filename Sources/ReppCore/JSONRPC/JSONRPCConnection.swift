import Foundation

public protocol JSONRPCTransport: Sendable {
    /// Sends one complete JSON message, WITHOUT a trailing newline.
    func send(_ frame: Data) async throws
    /// Yields one complete JSON message (no trailing newline) per element.
    var incoming: AsyncStream<Data> { get }
    func close() async
}

public actor JSONRPCConnection {
    private let transport: any JSONRPCTransport
    private var nextRequestID = 0
    private var pendingRequests: [Int: CheckedContinuation<JSONValue, Error>] = [:]
    private var readTask: Task<Void, Never>?
    private var isClosed = false
    private var requestHandler: (@Sendable (String, JSONValue?) async -> Result<JSONValue, JSONRPCError>)?

    private let notificationsContinuation: AsyncStream<JSONRPCIncomingNotification>.Continuation
    public let notifications: AsyncStream<JSONRPCIncomingNotification>

    public init(transport: any JSONRPCTransport) {
        self.transport = transport
        var continuation: AsyncStream<JSONRPCIncomingNotification>.Continuation!
        self.notifications = AsyncStream { continuation = $0 }
        self.notificationsContinuation = continuation
    }

    public func start() {
        guard readTask == nil else { return }
        readTask = Task { [weak self] in
            guard let self else { return }
            await self.readLoop()
        }
    }

    public func close() async {
        guard !isClosed else { return }
        isClosed = true
        readTask?.cancel()
        await transport.close()
        failAllPending(with: JSONRPCConnectionError.connectionClosed)
        notificationsContinuation.finish()
    }

    public func request<R: Decodable & Sendable>(method: String, params: JSONValue?) async throws -> R {
        let result = try await requestRaw(method: method, params: params)
        let data: Data
        do {
            data = try JSONEncoder().encode(result)
        } catch {
            throw JSONRPCConnectionError.invalidResponse("failed to re-encode result: \(error)")
        }
        do {
            return try JSONDecoder().decode(R.self, from: data)
        } catch {
            throw JSONRPCConnectionError.invalidResponse("failed to decode result as \(R.self): \(error)")
        }
    }

    public func requestRaw(method: String, params: JSONValue?) async throws -> JSONValue {
        guard !isClosed else { throw JSONRPCConnectionError.connectionClosed }
        let id = nextRequestID
        nextRequestID += 1
        let frame = encode(JSONRPCFrameBuilder.request(id: id, method: method, params: params))

        return try await withCheckedThrowingContinuation { continuation in
            pendingRequests[id] = continuation
            Task {
                do {
                    try await self.transport.send(frame)
                } catch {
                    self.failPending(id: id, error: error)
                }
            }
        }
    }

    public func notify(method: String, params: JSONValue?) async throws {
        guard !isClosed else { throw JSONRPCConnectionError.connectionClosed }
        let frame = encode(JSONRPCFrameBuilder.notification(method: method, params: params))
        try await transport.send(frame)
    }

    public func setRequestHandler(
        _ handler: @Sendable @escaping (String, JSONValue?) async -> Result<JSONValue, JSONRPCError>
    ) {
        requestHandler = handler
    }

    private func readLoop() async {
        for await data in transport.incoming {
            await handle(data)
        }
        failAllPending(with: JSONRPCConnectionError.connectionClosed)
    }

    private func handle(_ data: Data) async {
        switch JSONRPCIncomingFrame.parse(data) {
        case .response(let id, let result, let error):
            guard let continuation = pendingRequests.removeValue(forKey: id) else { return }
            if let error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: result ?? .null)
            }
        case .notification(let method, let params):
            notificationsContinuation.yield(JSONRPCIncomingNotification(method: method, params: params))
        case .serverRequest(let id, let method, let params):
            await handleServerRequest(id: id, method: method, params: params)
        case .malformed:
            break
        }
    }

    private func handleServerRequest(id: JSONValue, method: String, params: JSONValue?) async {
        let result: Result<JSONValue, JSONRPCError>
        if let requestHandler {
            result = await requestHandler(method, params)
        } else {
            result = .failure(
                JSONRPCError(code: JSONRPCStatusCode.methodNotFound, message: "Method not found: \(method)")
            )
        }
        let frame: JSONValue
        switch result {
        case .success(let value):
            frame = JSONRPCFrameBuilder.response(id: id, result: value)
        case .failure(let error):
            frame = JSONRPCFrameBuilder.errorResponse(id: id, error: error)
        }
        try? await transport.send(encode(frame))
    }

    private func failPending(id: Int, error: Error) {
        pendingRequests.removeValue(forKey: id)?.resume(throwing: error)
    }

    private func failAllPending(with error: Error) {
        let continuations = pendingRequests
        pendingRequests.removeAll()
        for continuation in continuations.values {
            continuation.resume(throwing: error)
        }
    }

    private func encode(_ value: JSONValue) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }
}
