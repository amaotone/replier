import Testing
@testable import ReplierCore

private final class StubDrafter: ReplyDrafting, @unchecked Sendable {
    enum Behavior {
        case chunks([String])
        case error(Error)
    }

    private let behavior: Behavior
    private(set) var capturedRequest: ReplyRequest?
    private(set) var callCount = 0

    init(chunks: [String]) {
        self.behavior = .chunks(chunks)
    }

    init(error: Error) {
        self.behavior = .error(error)
    }

    func draft(_ request: ReplyRequest) async throws -> AsyncThrowingStream<String, Error> {
        capturedRequest = request
        callCount += 1
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

/// Simulates a sequence of generations from the same drafter instance, where earlier
/// calls can "hang" (yield once, then never yield or finish again) to exercise
/// regenerate-cancels-previous behavior. `cancelledCallIndices` records which calls'
/// streams observed the consuming task being cancelled.
private final class SequencedDrafter: ReplyDrafting, @unchecked Sendable {
    enum Behavior {
        case hang(firstChunk: String)
        case complete(chunks: [String])
    }

    private let behaviors: [Behavior]
    private var callIndex = 0
    let cancelledCallIndices = CancelledTracker()

    init(behaviors: [Behavior]) {
        self.behaviors = behaviors
    }

    func draft(_ request: ReplyRequest) async throws -> AsyncThrowingStream<String, Error> {
        let index = callIndex
        callIndex += 1
        let behavior = behaviors[min(index, behaviors.count - 1)]
        let tracker = cancelledCallIndices

        switch behavior {
        case .hang(let firstChunk):
            return AsyncThrowingStream { continuation in
                continuation.onTermination = { _ in tracker.markCancelled(index) }
                continuation.yield(firstChunk)
                // Deliberately never yields again and never finishes.
            }
        case .complete(let chunks):
            return AsyncThrowingStream { continuation in
                for chunk in chunks {
                    continuation.yield(chunk)
                }
                continuation.finish()
            }
        }
    }
}

private final class CancelledTracker: @unchecked Sendable {
    private var indices: Set<Int> = []
    func markCancelled(_ index: Int) { indices.insert(index) }
    func contains(_ index: Int) -> Bool { indices.contains(index) }
}

private struct StubError: Error, Equatable {}

private let validSentinelText = """
<<<short>>>
了解です。
<<<long>>>
承知しました。内容を確認の上、対応いたします。ご不明な点があれば改めてご連絡します。
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

/// Polls a MainActor-isolated `condition` until it is true or `timeout` elapses. A
/// file-local counterpart to the module's `nonisolated waitUntil(_:)` helper, needed
/// because sending a closure that captures `@MainActor`-isolated state (e.g. `PanelModel`)
/// across to a nonisolated function trips Swift 6 strict concurrency checks.
@MainActor
private func waitUntilOnMain(timeout: Duration = .seconds(2), _ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        if ContinuousClock.now >= deadline {
            struct TimedOut: Error {}
            throw TimedOut()
        }
        try await Task.sleep(for: .milliseconds(5))
    }
}

@MainActor
@Suite struct PanelModelTests {
    @Test func initialPhaseIsComposing() {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(chunks: []),
            style: StyleProfile()
        )
        #expect(model.phase == .composing)
    }

    @Test func noGenerationStartsOnInit() async throws {
        let drafter = StubDrafter(chunks: chunked(validSentinelText))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        // Give any stray background work a chance to run before asserting nothing did.
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.phase == .composing)
        #expect(model.partials.isEmpty)
        #expect(drafter.capturedRequest == nil)
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

    @Test func mailContextDefaultsSituationToMail() {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(chunks: []),
            style: StyleProfile()
        )
        #expect(model.situation == .mail)
    }

    @Test func nonMailContextDefaultsSituationToChat() {
        for sourceApp: SourceApp in [.slack, .browser, .other] {
            let model = PanelModel(
                contextText: "hello",
                sourceApp: sourceApp,
                drafter: StubDrafter(chunks: []),
                style: StyleProfile()
            )
            #expect(model.situation == .chat)
        }
    }

    @Test func submitStartsGenerationImmediatelyAndPassesGistThroughToDrafter() async throws {
        let drafter = StubDrafter(chunks: chunked(validSentinelText))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.instruction = "承諾する返信を作成してください。"
        model.submit()
        // submit() returns synchronously already in .generating, before the background
        // generation task has necessarily run.
        #expect(model.phase == .generating || model.phase == .ready)

        try await waitUntilOnMain { model.phase == .ready }
        #expect(drafter.capturedRequest?.gist == "承諾する返信を作成してください。")
    }

    @Test func submitPassesSituationThroughToDrafter() async throws {
        let drafter = StubDrafter(chunks: chunked(validSentinelText))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )
        model.situation = .chat

        model.instruction = "承諾する返信を作成してください。"
        model.submit()
        try await waitUntilOnMain { model.phase == .ready }
        #expect(drafter.capturedRequest?.situation == .chat)
    }

    @Test func submitEndsReadyWithTwoParsedCandidatesAndShortSelected() async throws {
        let drafter = StubDrafter(chunks: chunked(validSentinelText))
        let model = PanelModel(
            contextText: "会議の件、了解しました",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.instruction = "承諾する返信を作成してください。"
        model.submit()
        try await waitUntilOnMain { model.phase == .ready }

        #expect(model.partials.count == 2)
        #expect(model.selectedIndex == 0)
        #expect(model.partials[0].label == .short)
        #expect(model.partials[1].label == .long)
        #expect(model.partials.allSatisfy { $0.isComplete })
    }

    @Test func submitPassesThroughGeneratingWithGrowingPartialsThenReady() async {
        let chunks = chunked(validSentinelText, size: 6)
        let drafter = DelayedDrafter(chunks: chunks)
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.instruction = "承諾する返信を作成してください。"
        model.submit()

        var observedCounts: [Int] = []
        for _ in 0..<800 {
            if observedCounts.last != model.partials.count {
                observedCounts.append(model.partials.count)
            }
            if model.phase == .ready {
                break
            }
            try? await Task.sleep(nanoseconds: 2_000_000)
        }

        #expect(model.phase == .ready)
        #expect(observedCounts == observedCounts.sorted())
        #expect(observedCounts.first == 0)
        #expect(observedCounts.last == 2)
    }

    @Test func singleCandidateAtFinishStillResultsInReady() async throws {
        let drafter = StubDrafter(chunks: chunked("<<<short>>>\n短めの返信だけ"))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.instruction = "承諾する返信を作成してください。"
        model.submit()
        try await waitUntilOnMain { model.phase == .ready }

        #expect(model.partials.count == 1)
        #expect(model.partials[0].label == .short)
        #expect(model.partials[0].isComplete)
    }

    @Test func streamErrorResultsInFailed() async throws {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(error: StubError()),
            style: StyleProfile()
        )

        model.instruction = "承諾する返信を作成してください。"
        model.submit()
        try await waitUntilOnMain {
            if case .failed = model.phase { return true }
            return false
        }
    }

    @Test func zeroCandidatesResultsInFailed() async throws {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(chunks: ["sentinelを含まないプレーンテキストです"]),
            style: StyleProfile()
        )

        model.instruction = "承諾する返信を作成してください。"
        model.submit()
        try await waitUntilOnMain {
            if case .failed = model.phase { return true }
            return false
        }
        #expect(model.partials.isEmpty)
    }

    @Test func moveSelectionWrapsAroundWhenReady() async throws {
        let drafter = StubDrafter(chunks: chunked(validSentinelText))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.instruction = "承諾する返信を作成してください。"
        model.submit()
        try await waitUntilOnMain { model.phase == .ready }
        #expect(model.selectedIndex == 0)

        model.moveSelection(-1)
        #expect(model.selectedIndex == 1)
        model.moveSelection(1)
        #expect(model.selectedIndex == 0)
        model.moveSelection(1)
        #expect(model.selectedIndex == 1)
    }

    @Test func moveSelectionNavigatesOverPartialsWhileGenerating() async throws {
        let drafter = SequencedDrafter(behaviors: [
            .hang(firstChunk: "<<<short>>>\n短め\n<<<long>>>\n長め\n"),
        ])
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.instruction = "承諾する返信を作成してください。"
        model.submit()
        try await waitUntilOnMain { model.partials.count == 2 }

        #expect(model.selectedIndex == 0)
        model.moveSelection(1)
        #expect(model.selectedIndex == 1)
    }

    @Test func selectedTextIsNilBeforeAnyCandidateArrives() {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(chunks: []),
            style: StyleProfile()
        )
        #expect(model.selectedText == nil)
    }

    @Test func selectedTextRequiresCandidateToBeComplete() async throws {
        let drafter = SequencedDrafter(behaviors: [
            .hang(firstChunk: "<<<short>>>\n短め\n<<<long>>>\n進行中\n"),
        ])
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.instruction = "承諾する返信を作成してください。"
        model.submit()
        try await waitUntilOnMain { model.partials.count == 2 }

        #expect(model.partials[0].isComplete)
        #expect(model.selectedText == "短め")

        model.moveSelection(1)
        #expect(model.partials[1].isComplete == false)
        #expect(model.selectedText == nil)
    }

    @Test func selectedTextReturnsSelectedCandidateTextWhenReady() async throws {
        let drafter = StubDrafter(chunks: chunked(validSentinelText))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.instruction = "承諾する返信を作成してください。"
        model.submit()
        try await waitUntilOnMain { model.phase == .ready }
        #expect(model.selectedText == "了解です。")

        model.moveSelection(-1)
        #expect(model.selectedText == "承知しました。内容を確認の上、対応いたします。ご不明な点があれば改めてご連絡します。")
    }

    @Test func resetToComposingReturnsFromFailedToComposingAndClearsPartials() async throws {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(error: StubError()),
            style: StyleProfile()
        )

        model.instruction = "承諾する返信を作成してください。"
        model.submit()
        try await waitUntilOnMain {
            if case .failed = model.phase { return true }
            return false
        }

        model.resetToComposing()
        #expect(model.phase == .composing)
        #expect(model.partials.isEmpty)
    }

    @Test func submitPassesInstructionThroughToDrafterAsGist() async throws {
        let drafter = StubDrafter(chunks: chunked(validSentinelText))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.instruction = "英語で返信してください"
        model.submit()
        try await waitUntilOnMain { model.phase == .ready }

        #expect(drafter.capturedRequest?.gist == "英語で返信してください")
    }

    @Test func submitWithEmptyTextIsNoOp() async throws {
        let drafter = StubDrafter(chunks: chunked(validSentinelText))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.instruction = "   "
        model.submit()

        try await Task.sleep(for: .milliseconds(50))

        #expect(model.phase == .composing)
        #expect(model.partials.isEmpty)
        #expect(drafter.callCount == 0)
    }

    @Test func submitDuringGenerationCancelsPreviousAndStartsNew() async throws {
        let drafter = SequencedDrafter(behaviors: [
            .hang(firstChunk: "<<<short>>>\n古い生成中\n"),
            .complete(chunks: chunked(validSentinelText)),
        ])
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.instruction = "最初の指示"
        model.submit()
        try await waitUntilOnMain { !model.partials.isEmpty }
        #expect(model.partials.first?.text == "古い生成中")

        model.instruction = "新しい指示"
        model.submit()
        try await waitUntilOnMain { model.phase == .ready }

        #expect(model.partials.count == 2)
        #expect(model.partials[0].text == "了解です。")
        #expect(drafter.cancelledCallIndices.contains(0))
    }

    @Test func applyPresetSetsInstructionAndGeneratesImmediately() async throws {
        let drafter = StubDrafter(chunks: chunked(validSentinelText))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.applyPreset("わかりました")
        #expect(model.instruction == "わかりました")
        #expect(model.phase == .generating || model.phase == .ready)

        try await waitUntilOnMain { model.phase == .ready }
        #expect(drafter.capturedRequest?.gist == "わかりました")
    }

    @Test func applyPresetWhilePreviousGenerationStuckCancelsItAndReflectsOnlyTheNewOne() async throws {
        let drafter = SequencedDrafter(behaviors: [
            .hang(firstChunk: "<<<short>>>\n古い生成中\n"),
            .complete(chunks: chunked(validSentinelText)),
        ])
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.applyPreset("わかりました")
        try await waitUntilOnMain { !model.partials.isEmpty }
        #expect(model.partials.first?.text == "古い生成中")

        // Simulates tapping another preset while the first generation is still stuck.
        model.applyPreset("ごめんなさい")
        try await waitUntilOnMain { model.phase == .ready }

        #expect(model.instruction == "ごめんなさい")
        #expect(model.partials.count == 2)
        #expect(model.partials[0].text == "了解です。")
        #expect(drafter.cancelledCallIndices.contains(0))
    }

    @Test func regenerateIsNoOpBeforeAnyGeneration() async throws {
        let drafter = StubDrafter(chunks: chunked(validSentinelText))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.regenerate()
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.phase == .composing)
        #expect(drafter.callCount == 0)
    }

    @Test func regenerateReusesLastGistAfterApplyPreset() async throws {
        let drafter = StubDrafter(chunks: chunked(validSentinelText))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.applyPreset("確認します")
        try await waitUntilOnMain { model.phase == .ready }

        model.regenerate()
        try await waitUntilOnMain { drafter.callCount == 2 }
        #expect(drafter.capturedRequest?.gist == "確認します")
    }

    @Test func cancellingViaConfirmSelectionDoesNotFlipPhaseToFailed() async throws {
        let drafter = SequencedDrafter(behaviors: [
            .hang(firstChunk: "<<<short>>>\n短めの案\n<<<long>>>\n進行中\n"),
        ])
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.instruction = "承諾する返信を作成してください。"
        model.submit()
        try await waitUntilOnMain { model.partials.first?.isComplete == true }

        let confirmed = model.confirmSelection()
        #expect(confirmed == "短めの案")

        try await waitUntilOnMain { drafter.cancelledCallIndices.contains(0) }

        if case .failed = model.phase {
            Issue.record("cancellation should not result in .failed")
        }
    }

    @Test func changingToneDoesNotStartGeneration() async throws {
        let drafter = StubDrafter(chunks: chunked(validSentinelText))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.tone = .casual
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.phase == .composing)
        #expect(drafter.callCount == 0)
    }

    @Test func changingSituationDoesNotStartGeneration() async throws {
        let drafter = StubDrafter(chunks: chunked(validSentinelText))
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: drafter,
            style: StyleProfile()
        )

        model.situation = .chat
        try await Task.sleep(for: .milliseconds(50))

        #expect(model.phase == .composing)
        #expect(drafter.callCount == 0)
    }

    @Test func requestFocusIncrementsFocusRequestCounter() {
        let model = PanelModel(
            contextText: "hello",
            sourceApp: .mail,
            drafter: StubDrafter(chunks: []),
            style: StyleProfile()
        )
        #expect(model.focusRequest == 0)
        model.requestFocus()
        #expect(model.focusRequest == 1)
        model.requestFocus()
        #expect(model.focusRequest == 2)
    }
}
