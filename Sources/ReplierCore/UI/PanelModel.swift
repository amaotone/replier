import Observation

@MainActor
@Observable
public final class PanelModel {
    public enum Phase: Equatable {
        case composing
        case generating
        case ready
        case failed(String)
    }

    public private(set) var phase: Phase = .composing
    public var contextText: String
    public let sourceApp: SourceApp
    public var tone: Tone
    public var situation: Situation
    /// The 返信欄 text: the user's one-line gist/instruction for the reply. Bound
    /// directly by `PanelView`'s instruction field and read by `submit()`.
    public var instruction: String = ""
    public private(set) var partials: [PartialCandidate] = []
    public private(set) var selectedIndex: Int = 0
    public private(set) var lastGist: String?
    /// Bumped by `PanelController.show()` right after the panel becomes key. `PanelView`
    /// observes this via `.onChange` to reliably refocus the instruction field on every
    /// open/reopen — a plain SwiftUI `.onAppear` fires before a non-activating `NSPanel`
    /// hosted in an `NSHostingView` actually becomes key, so it can't be trusted alone.
    public private(set) var focusRequest: Int = 0

    private let drafter: any ReplyDrafting
    private let style: StyleProfile
    private var generationTask: Task<Void, Never>?
    private var currentGeneration = 0

    public init(contextText: String, sourceApp: SourceApp, drafter: any ReplyDrafting, style: StyleProfile) {
        self.contextText = contextText
        self.sourceApp = sourceApp
        self.tone = sourceApp == .slack ? .casual : .business
        self.situation = sourceApp == .mail ? .mail : .chat
        self.drafter = drafter
        self.style = style
    }

    public func requestFocus() {
        focusRequest += 1
    }

    /// Cancels any in-flight generation and starts a new one with the given gist. Safe to
    /// call while a generation is already streaming (e.g. a second preset tap acting as
    /// "regenerate"). Tone/situation edits do NOT call this — they only update state,
    /// taking effect at the next explicit generation.
    private func generate(gist: String) {
        generationTask?.cancel()
        currentGeneration += 1
        let generation = currentGeneration
        lastGist = gist

        phase = .generating
        partials = []
        selectedIndex = 0

        let request = ReplyRequest(
            context: CapturedContext(text: contextText, sourceApp: sourceApp),
            gist: gist,
            tone: tone,
            situation: situation,
            style: style
        )

        generationTask = Task { @MainActor [weak self] in
            await self?.runGeneration(request: request, generation: generation)
        }
    }

    /// Re-runs generation with whatever gist was last used. No-op if nothing has been
    /// generated yet (e.g. called from the "やり直す" retry button before any `submit`).
    public func regenerate() {
        guard let lastGist else { return }
        generate(gist: lastGist)
    }

    /// Submits the current `instruction` text. Empty/whitespace text is a no-op and
    /// leaves `phase` unchanged — there is no おまかせ(auto) fallback.
    public func submit() {
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        generate(gist: trimmed)
    }

    /// Sets `instruction` to a preset gist and immediately generates, so the user sees
    /// what was used and can edit + resubmit.
    public func applyPreset(_ gist: String) {
        instruction = gist
        generate(gist: gist)
    }

    private func isStale(_ generation: Int) -> Bool {
        generation != currentGeneration || Task.isCancelled
    }

    private func runGeneration(request: ReplyRequest, generation: Int) async {
        var parser = IncrementalCandidateParser()

        do {
            let stream = try await drafter.draft(request)
            for try await chunk in stream {
                if isStale(generation) { return }
                partials = parser.feed(chunk)
            }
        } catch {
            if isStale(generation) { return }
            phase = .failed(String(describing: error))
            return
        }

        if isStale(generation) { return }

        let final = parser.finish()
        partials = final
        if final.contains(where: { !$0.text.isEmpty }) {
            phase = .ready
            selectedIndex = final.firstIndex(where: { $0.label == .short }) ?? 0
        } else {
            phase = .failed("返信案を生成できませんでした。")
        }
    }

    public func resetToComposing() {
        generationTask?.cancel()
        phase = .composing
        partials = []
        selectedIndex = 0
    }

    public func moveSelection(_ delta: Int) {
        guard !partials.isEmpty else { return }
        let count = partials.count
        selectedIndex = ((selectedIndex + delta) % count + count) % count
    }

    /// The selected candidate's text, but only once it has finished streaming — earlier
    /// candidates remain confirmable even while later ones are still in flight.
    public var selectedText: String? {
        guard partials.indices.contains(selectedIndex) else { return nil }
        let candidate = partials[selectedIndex]
        return candidate.isComplete ? candidate.text : nil
    }

    /// Returns the selected candidate's text (if confirmable) and cancels the in-flight
    /// generation so a stray late chunk can't mutate state after the panel is dismissed.
    @discardableResult
    public func confirmSelection() -> String? {
        guard let text = selectedText else { return nil }
        generationTask?.cancel()
        return text
    }
}
