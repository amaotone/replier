import Testing
@testable import ReplierCore

private final class StubDrafter: ReplyDrafting, @unchecked Sendable {
    enum Behavior {
        case chunks([String])
        case error(Error)
    }

    private let behavior: Behavior
    private(set) var capturedRequest: ReplyRequest?

    init(chunks: [String]) {
        self.behavior = .chunks(chunks)
    }

    init(error: Error) {
        self.behavior = .error(error)
    }

    func draft(_ request: ReplyRequest) async throws -> AsyncThrowingStream<String, Error> {
        capturedRequest = request
        switch behavior {
        case .chunks(let chunks):
            return AsyncThrowingStream { continuation in
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        case .error(let error):
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
    }
}

/// Yields chunks with a small real delay between them so a concurrently running
/// observer has a chance to see intermediate `.generating` phases.
private final class DelayedDrafter: ReplyDrafting, @unchecked Sendable {
    private let chunks: [String]
    private let delayNanoseconds: UInt64

    init(chunks: [String], delayNanoseconds: UInt64 = 5_000_000) {
        self.chunks = chunks
        self.delayNanoseconds = delayNanoseconds
    }

    func draft(_ request: ReplyRequest) async throws -> AsyncThrowingStream<String, Error> {
        let chunks = self.chunks
        let delayNanoseconds = self.delayNanoseconds
        return AsyncThrowingStream { continuation in
            Task {
                for chunk in chunks {
                    try? await Task.sleep(nanoseconds: delayNanoseconds)
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }
}

private struct StubError: Error, Equatable {}

private let validJSON = """
{"candidates":[{"label":"short","text":"了解です。"},{"label":"standard","text":"承知しました。対応します。"},{"label":"polite","text":"ご連絡いただきありがとうございます。承知いたしました。"}]}
"""

private func chunked(_ text: String, size: Int = 8) -> [String] {
    var chunks: [String] = []
    var current = text.startIndex
    while current < text.endIndex {
        let next = text.index(current, offsetBy: size, limitedBy: text.endIndex) ?? text.endIndex
        chunks.append(String(text[current..<next]))
        current = next
    }
    return chunks
}

@MainActor
@Suite struct PanelModelTests {
    @Test func initialPhaseIsChoosing() {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(chunks: []),
            style: StyleProfile()
        )
        #expect(model.phase == .choosing)
    }

    @Test func slackContextDefaultsToneToCasual() {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .slack,
            drafter: StubDrafter(chunks: []),
            style: StyleProfile()
        )
        #expect(model.tone == .casual)
    }

    @Test func mailContextDefaultsToneToBusiness() {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(chunks: []),
            style: StyleProfile()
        )
        #expect(model.tone == .business)
    }

    @Test func chooseEndsReadyWithThreeParsedCandidatesAndStandardSelected() async {
        let drafter = StubDrafter(chunks: chunked(validJSON))
        let model = PanelModel(
            contextText: "会議の件、了解しました",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )
        await model.choose(intent: .accept)

        #expect(model.phase == .ready)
        #expect(model.candidates.count == 3)
        #expect(model.selectedIndex == 1)
        #expect(model.candidates[0].label == .short)
        #expect(model.candidates[1].label == .standard)
        #expect(model.candidates[2].label == .polite)
    }

    @Test func choosePassesThroughGeneratingWithGrowingCharCountThenReady() async {
        let chunks = chunked(validJSON, size: 6)
        let drafter = DelayedDrafter(chunks: chunks)
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        let task = Task { @MainActor in
            await model.choose(intent: .accept)
        }

        var observedCounts: [Int] = []
        for _ in 0..<800 {
            if case .generating(let count) = model.phase, observedCounts.last != count {
                observedCounts.append(count)
            }
            if model.phase == .ready {
                break
            }
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        await task.value

        #expect(model.phase == .ready)
        #expect(!observedCounts.isEmpty)
        #expect(observedCounts == observedCounts.sorted())
        #expect(observedCounts.last ?? 0 > 0)
    }

    @Test func streamErrorResultsInFailed() async {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(error: StubError()),
            style: StyleProfile()
        )
        await model.choose(intent: .accept)

        guard case .failed = model.phase else {
            Issue.record("expected .failed, got \(model.phase)")
            return
        }
    }

    @Test func unparsableFinalTextResultsInFailed() async {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(chunks: ["this is not json"]),
            style: StyleProfile()
        )
        await model.choose(intent: .accept)

        guard case .failed = model.phase else {
            Issue.record("expected .failed, got \(model.phase)")
            return
        }
    }

    @Test func moveSelectionWrapsAround() async {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(chunks: chunked(validJSON)),
            style: StyleProfile()
        )
        await model.choose(intent: .accept)
        #expect(model.selectedIndex == 1)

        model.moveSelection(-1)
        #expect(model.selectedIndex == 0)
        model.moveSelection(-1)
        #expect(model.selectedIndex == 2)
        model.moveSelection(1)
        #expect(model.selectedIndex == 0)
    }

    @Test func moveSelectionIsNoOpWhileGenerating() async {
        let drafter = DelayedDrafter(chunks: chunked(validJSON, size: 6))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        let task = Task { @MainActor in
            await model.choose(intent: .accept)
        }

        var sawGenerating = false
        for _ in 0..<400 {
            if case .generating = model.phase {
                sawGenerating = true
                model.moveSelection(1)
                #expect(model.selectedIndex == 0)
                break
            }
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        #expect(sawGenerating)

        await task.value
    }

    @Test func selectedTextIsNilUnlessReady() {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(chunks: []),
            style: StyleProfile()
        )
        #expect(model.selectedText == nil)
    }

    @Test func selectedTextReturnsSelectedCandidateTextWhenReady() async {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(chunks: chunked(validJSON)),
            style: StyleProfile()
        )
        await model.choose(intent: .accept)
        #expect(model.selectedText == "承知しました。対応します。")

        model.moveSelection(-1)
        #expect(model.selectedText == "了解です。")
    }

    @Test func resetToChoosingReturnsFromFailedToChoosingAndClearsCandidates() async {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(error: StubError()),
            style: StyleProfile()
        )
        await model.choose(intent: .accept)
        guard case .failed = model.phase else {
            Issue.record("expected .failed before reset, got \(model.phase)")
            return
        }

        model.resetToChoosing()
        #expect(model.phase == .choosing)
        #expect(model.candidates.isEmpty)
    }

    @Test func chooseWithCustomIntentPassesInstructionThroughToDrafter() async {
        let drafter = StubDrafter(chunks: chunked(validJSON))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )
        await model.choose(intent: .custom("英語で返信してください"))

        guard case .custom(let instruction) = drafter.capturedRequest?.intent else {
            Issue.record("expected custom intent to be captured")
            return
        }
        #expect(instruction == "英語で返信してください")
    }
}
