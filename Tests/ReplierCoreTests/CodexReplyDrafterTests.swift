import Foundation
import Testing
@testable import ReplierCore

@Suite struct CodexReplyDrafterTests {
    private func request() -> ReplyRequest {
        ReplyRequest(
            context: CapturedContext(text: "明日の会議の件", sourceApp: .mail),
            gist: "承諾する返信を作成してください。",
            tone: .business,
            situation: .mail,
            style: StyleProfile(),
            format: .plain,
            language: .auto
        )
    }

    @Test func defaultReasoningEffortIsMinimalAndOptionsSpanNoneToXhigh() {
        #expect(CodexSettings.defaultReasoningEffort == "minimal")
        #expect(CodexSettings.reasoningEffortOptions == ["none", "minimal", "low", "medium", "high", "xhigh"])
    }

    @Test func draftThrowsDescriptiveErrorWhenCodexIsNotFound() async throws {
        let drafter = CodexReplyDrafter(client: nil)

        do {
            _ = try await drafter.draft(request())
            Issue.record("expected draft to throw")
        } catch let error as CodexReplyDrafter.DrafterError {
            #expect(error == .codexNotFound)
            #expect(error.description.contains("brew install codex"))
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test func draftStartsClientBuildsPromptAndStreamsDeltas() async throws {
        let transport = InMemoryTransport()
        let client = CodexAppServerClient(transport: transport)
        let drafter = CodexReplyDrafter(client: client)

        async let streamResult = drafter.draft(request())

        try await waitUntil { !transport.sentFrames.isEmpty }
        guard case .number(let initId)? = transport.sentJSON(at: 0)?["id"] else {
            Issue.record("initialize request missing numeric id")
            return
        }
        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(initId),
            "result": .object([
                "codexHome": .string("/tmp/codex-home"),
                "platformFamily": .string("unix"),
                "platformOs": .string("macos"),
                "userAgent": .string("codex-test"),
            ]),
        ]))

        try await waitUntil { transport.sentFrames.count >= 3 }
        let threadStartFrame = transport.sentJSON(at: 2)
        #expect(threadStartFrame?["method"] == .string("thread/start"))
        guard case .string(let developerInstructions)? = threadStartFrame?["params"]?["developerInstructions"] else {
            Issue.record("thread/start request missing developerInstructions")
            return
        }
        #expect(developerInstructions.contains("ビジネスにふさわしい丁寧さ"))
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
            "method": .string("item/agentMessage/delta"),
            "params": .object([
                "threadId": .string("thread-1"),
                "turnId": .string("turn-1"),
                "itemId": .string("item-1"),
                "delta": .string("承知しました"),
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
        #expect(collected == ["承知しました"])
    }

    @Test func draftUsesConfiguredModelAndReasoningEffortFromUserDefaults() async throws {
        let suiteName = "CodexReplyDrafterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("custom-model", forKey: CodexSettings.modelDefaultsKey)
        defaults.set("low", forKey: CodexSettings.reasoningEffortDefaultsKey)

        let transport = InMemoryTransport()
        let client = CodexAppServerClient(transport: transport)
        let drafter = CodexReplyDrafter(client: client, userDefaults: defaults)

        async let streamResult = drafter.draft(request())

        try await waitUntil { !transport.sentFrames.isEmpty }
        guard case .number(let initId)? = transport.sentJSON(at: 0)?["id"] else {
            Issue.record("initialize request missing numeric id")
            return
        }
        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(initId),
            "result": .object([
                "codexHome": .string("/tmp/codex-home"),
                "platformFamily": .string("unix"),
                "platformOs": .string("macos"),
                "userAgent": .string("codex-test"),
            ]),
        ]))

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
        let turnStartFrame = transport.sentJSON(at: 3)
        #expect(turnStartFrame?["params"]?["model"] == .string("custom-model"))
        #expect(turnStartFrame?["params"]?["effort"] == .string("low"))
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
            "method": .string("turn/completed"),
            "params": .object([
                "threadId": .string("thread-1"),
                "turn": .object(["id": .string("turn-1"), "status": .string("completed"), "items": .array([])]),
            ]),
        ]))
        for try await _ in stream {}
    }

    @Test func draftFallsBackToDefaultModelAndEffortWhenUnset() async throws {
        let suiteName = "CodexReplyDrafterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let transport = InMemoryTransport()
        let client = CodexAppServerClient(transport: transport)
        let drafter = CodexReplyDrafter(client: client, userDefaults: defaults)

        async let streamResult = drafter.draft(request())

        try await waitUntil { !transport.sentFrames.isEmpty }
        guard case .number(let initId)? = transport.sentJSON(at: 0)?["id"] else {
            Issue.record("initialize request missing numeric id")
            return
        }
        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(initId),
            "result": .object([
                "codexHome": .string("/tmp/codex-home"),
                "platformFamily": .string("unix"),
                "platformOs": .string("macos"),
                "userAgent": .string("codex-test"),
            ]),
        ]))

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
        let turnStartFrame = transport.sentJSON(at: 3)
        #expect(turnStartFrame?["params"]?["model"] == .string(CodexSettings.defaultModel))
        #expect(turnStartFrame?["params"]?["effort"] == .string(CodexSettings.defaultReasoningEffort))
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
            "method": .string("turn/completed"),
            "params": .object([
                "threadId": .string("thread-1"),
                "turn": .object(["id": .string("turn-1"), "status": .string("completed"), "items": .array([])]),
            ]),
        ]))
        for try await _ in stream {}
    }

    @Test func prewarmThenDraftSendsOnlyOneInitializeHandshake() async throws {
        let transport = InMemoryTransport()
        let client = CodexAppServerClient(transport: transport)
        let drafter = CodexReplyDrafter(client: client)

        async let prewarmResult: Void = drafter.prewarm()

        try await waitUntil { !transport.sentFrames.isEmpty }
        guard case .number(let initId)? = transport.sentJSON(at: 0)?["id"] else {
            Issue.record("initialize request missing numeric id")
            return
        }
        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(initId),
            "result": .object([
                "codexHome": .string("/tmp/codex-home"),
                "platformFamily": .string("unix"),
                "platformOs": .string("macos"),
                "userAgent": .string("codex-test"),
            ]),
        ]))
        await prewarmResult

        try await waitUntil { transport.sentFrames.count >= 2 }
        #expect(initializeFrameCount(in: transport) == 1)

        async let streamResult = drafter.draft(request())

        try await waitUntil { transport.sentFrames.count >= 3 }
        let threadStartFrame = transport.sentJSON(at: 2)
        #expect(threadStartFrame?["method"] == .string("thread/start"))
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
            "method": .string("turn/completed"),
            "params": .object([
                "threadId": .string("thread-1"),
                "turn": .object(["id": .string("turn-1"), "status": .string("completed"), "items": .array([])]),
            ]),
        ]))
        for try await _ in stream {}

        #expect(initializeFrameCount(in: transport) == 1)
    }

    private func initializeFrameCount(in transport: InMemoryTransport) -> Int {
        transport.sentFrames
            .compactMap { try? JSONDecoder().decode(JSONValue.self, from: $0) }
            .filter { $0["method"] == .string("initialize") }
            .count
    }
}
