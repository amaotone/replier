import Foundation
import Testing
@testable import ReplierCore

@Suite struct CodexAppServerClientTests {
    private func startedClient(_ transport: InMemoryTransport) async throws -> CodexAppServerClient {
        let client = CodexAppServerClient(transport: transport)
        async let startResult: Void = client.start()

        try await waitUntil { !transport.sentFrames.isEmpty }
        guard case .number(let id)? = transport.sentJSON(at: 0)?["id"] else {
            Issue.record("initialize request missing numeric id")
            return client
        }
        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(id),
            "result": .object([
                "codexHome": .string("/tmp/codex-home"),
                "platformFamily": .string("unix"),
                "platformOs": .string("macos"),
                "userAgent": .string("codex-test"),
            ]),
        ]))
        try await startResult
        return client
    }

    @Test func startSendsInitializeThenInitializedNotification() async throws {
        let transport = InMemoryTransport()
        _ = try await startedClient(transport)

        try await waitUntil { transport.sentFrames.count >= 2 }

        let initializeFrame = transport.sentJSON(at: 0)
        #expect(initializeFrame?["method"] == .string("initialize"))
        #expect(initializeFrame?["params"]?["clientInfo"]?["name"] == .string("replier"))
        guard case .number? = initializeFrame?["id"] else {
            Issue.record("initialize request should carry a numeric id")
            return
        }

        let initializedFrame = transport.sentJSON(at: 1)
        #expect(initializedFrame?["method"] == .string("initialized"))
        #expect(initializedFrame?["id"] == nil)
    }

    @Test func draftRepliesStartsThreadThenTurnAndStreamsDeltasInOrder() async throws {
        let transport = InMemoryTransport()
        let client = try await startedClient(transport)

        let prompt = Prompt(system: "be terse", user: "say hi")
        async let streamResult: AsyncThrowingStream<String, Error> = client.draftReplies(prompt)

        try await waitUntil { transport.sentFrames.count >= 3 }
        let threadStartFrame = transport.sentJSON(at: 2)
        #expect(threadStartFrame?["method"] == .string("thread/start"))
        #expect(threadStartFrame?["params"]?["developerInstructions"] == .string("be terse"))
        guard case .number(let threadRequestId)? = threadStartFrame?["id"] else {
            Issue.record("thread/start request missing numeric id")
            return
        }
        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(threadRequestId),
            "result": .object(["thread": .object(["id": .string("thread-1")])]),
        ]))

        try await waitUntil { transport.sentFrames.count >= 4 }
        let turnStartFrame = transport.sentJSON(at: 3)
        #expect(turnStartFrame?["method"] == .string("turn/start"))
        #expect(turnStartFrame?["params"]?["threadId"] == .string("thread-1"))
        #expect(turnStartFrame?["params"]?["input"]?[0]?["type"] == .string("text"))
        #expect(turnStartFrame?["params"]?["input"]?[0]?["text"] == .string("say hi"))
        guard case .number(let turnRequestId)? = turnStartFrame?["id"] else {
            Issue.record("turn/start request missing numeric id")
            return
        }
        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(turnRequestId),
            "result": .object(["turn": .object(["id": .string("turn-1")])]),
        ]))

        let stream = try await streamResult

        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "method": .string("item/agentMessage/delta"),
            "params": .object([
                "threadId": .string("thread-1"),
                "turnId": .string("turn-1"),
                "itemId": .string("item-1"),
                "delta": .string("Hello"),
            ]),
        ]))
        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "method": .string("item/agentMessage/delta"),
            "params": .object([
                "threadId": .string("thread-1"),
                "turnId": .string("turn-1"),
                "itemId": .string("item-1"),
                "delta": .string(", world"),
            ]),
        ]))
        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "method": .string("turn/completed"),
            "params": .object([
                "threadId": .string("thread-1"),
                "turn": .object(["id": .string("turn-1"), "status": .string("completed"), "items": .array([])]),
            ]),
        ]))

        var collected: [String] = []
        for try await chunk in stream {
            collected.append(chunk)
        }
        #expect(collected == ["Hello", ", world"])
    }

    @Test func errorNotificationDuringTurnThrowsTurnFailed() async throws {
        let transport = InMemoryTransport()
        let client = try await startedClient(transport)

        async let streamResult: AsyncThrowingStream<String, Error> = client.draftReplies(
            Prompt(system: "sys", user: "usr")
        )

        try await waitUntil { transport.sentFrames.count >= 3 }
        guard case .number(let threadRequestId)? = transport.sentJSON(at: 2)?["id"] else {
            Issue.record("thread/start request missing numeric id")
            return
        }
        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(threadRequestId),
            "result": .object(["thread": .object(["id": .string("thread-1")])]),
        ]))

        try await waitUntil { transport.sentFrames.count >= 4 }
        guard case .number(let turnRequestId)? = transport.sentJSON(at: 3)?["id"] else {
            Issue.record("turn/start request missing numeric id")
            return
        }
        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(turnRequestId),
            "result": .object(["turn": .object(["id": .string("turn-1")])]),
        ]))

        let stream = try await streamResult

        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "method": .string("error"),
            "params": .object([
                "threadId": .string("thread-1"),
                "turnId": .string("turn-1"),
                "willRetry": .bool(false),
                "error": .object(["message": .string("model overloaded")]),
            ]),
        ]))

        do {
            for try await _ in stream {}
            Issue.record("expected the stream to throw")
        } catch let error as CodexClientError {
            #expect(error == .turnFailed("model overloaded"))
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test func accountStatusMapsLoggedInResponse() async throws {
        let transport = InMemoryTransport()
        let client = try await startedClient(transport)

        async let statusResult = client.accountStatus()

        try await waitUntil { transport.sentFrames.count >= 3 }
        let frame = transport.sentJSON(at: 2)
        #expect(frame?["method"] == .string("account/read"))
        guard case .number(let id)? = frame?["id"] else {
            Issue.record("account/read request missing numeric id")
            return
        }
        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(id),
            "result": .object([
                "requiresOpenaiAuth": .bool(false),
                "account": .object([
                    "type": .string("chatgpt"),
                    "email": .string("user@example.com"),
                    "planType": .string("pro"),
                ]),
            ]),
        ]))

        let status = try await statusResult
        #expect(status == CodexAccountStatus(isLoggedIn: true, plan: "pro"))
    }

    @Test func accountStatusMapsLoggedOutResponse() async throws {
        let transport = InMemoryTransport()
        let client = try await startedClient(transport)

        async let statusResult = client.accountStatus()

        try await waitUntil { transport.sentFrames.count >= 3 }
        guard case .number(let id)? = transport.sentJSON(at: 2)?["id"] else {
            Issue.record("account/read request missing numeric id")
            return
        }
        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(id),
            "result": .object([
                "requiresOpenaiAuth": .bool(true),
                "account": .null,
            ]),
        ]))

        let status = try await statusResult
        #expect(status == CodexAccountStatus(isLoggedIn: false, plan: nil))
    }

    @Test func serverInitiatedCommandApprovalIsRejected() async throws {
        let transport = InMemoryTransport()
        _ = try await startedClient(transport)

        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(42),
            "method": .string("item/commandExecution/requestApproval"),
            "params": .object([
                "threadId": .string("thread-1"),
                "turnId": .string("turn-1"),
                "itemId": .string("item-1"),
                "startedAtMs": .number(0),
            ]),
        ]))

        try await waitUntil { transport.sentFrames.count >= 3 }
        let response = transport.sentJSON(at: 2)
        #expect(response?["id"] == .number(42))
        #expect(response?["result"]?["decision"] == .string("decline"))
    }

    @Test func serverInitiatedFileChangeApprovalIsRejected() async throws {
        let transport = InMemoryTransport()
        _ = try await startedClient(transport)

        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(43),
            "method": .string("item/fileChange/requestApproval"),
            "params": .object([
                "threadId": .string("thread-1"),
                "turnId": .string("turn-1"),
                "itemId": .string("item-1"),
                "startedAtMs": .number(0),
            ]),
        ]))

        try await waitUntil { transport.sentFrames.count >= 3 }
        let response = transport.sentJSON(at: 2)
        #expect(response?["id"] == .number(43))
        #expect(response?["result"]?["decision"] == .string("decline"))
    }
}
