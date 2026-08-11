import Observation

@MainActor
@Observable
public final class PanelModel {
    public enum Phase: Equatable {
        case choosing
        case generating(charCount: Int)
        case ready
        case failed(String)
    }

    public private(set) var phase: Phase = .choosing
    public var contextText: String
    public let sourceApp: SourceApp
    public var tone: Tone
    public var customInstruction: String = ""
    public private(set) var candidates: [ReplyCandidate] = []
    public private(set) var selectedIndex: Int = 0

    private let drafter: any ReplyDrafting
    private let style: StyleProfile
    private let parser = CandidateParser()

    public init(contextText: String, sourceApp: SourceApp, drafter: any ReplyDrafting, style: StyleProfile) {
        self.contextText = contextText
        self.sourceApp = sourceApp
        self.tone = sourceApp == .slack ? .casual : .business
        self.drafter = drafter
        self.style = style
    }

    public func choose(intent: ReplyIntent) async {
        phase = .generating(charCount: 0)
        candidates = []

        let request = ReplyRequest(
            context: CapturedContext(text: contextText, sourceApp: sourceApp),
            intent: intent,
            tone: tone,
            style: style
        )

        var accumulated = ""
        do {
            let stream = try await drafter.draft(request)
            for try await chunk in stream {
                accumulated += chunk
                phase = .generating(charCount: accumulated.count)
            }
        } catch {
            phase = .failed(String(describing: error))
            return
        }

        do {
            let parsed = try parser.parse(accumulated)
            candidates = parsed
            selectedIndex = parsed.count == 3 ? 1 : 0
            phase = .ready
        } catch {
            phase = .failed(String(describing: error))
        }
    }

    public func resetToChoosing() {
        phase = .choosing
        candidates = []
    }

    public func moveSelection(_ delta: Int) {
        guard phase == .ready, !candidates.isEmpty else { return }
        let count = candidates.count
        selectedIndex = ((selectedIndex + delta) % count + count) % count
    }

    public var selectedText: String? {
        guard phase == .ready, candidates.indices.contains(selectedIndex) else { return nil }
        return candidates[selectedIndex].text
    }
}
