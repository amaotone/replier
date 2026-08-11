public enum SourceApp: String, Sendable, Codable, Equatable {
    case slack, mail, browser, other
}

public struct CapturedContext: Sendable, Equatable {
    public let text: String
    public let sourceApp: SourceApp

    public init(text: String, sourceApp: SourceApp) {
        self.text = text
        self.sourceApp = sourceApp
    }
}

public enum ReplyIntent: Sendable, Equatable {
    case accept, decline, question, followUp
    case custom(String)
}

public enum Tone: String, Sendable, Codable, CaseIterable {
    case business, casual
}

public struct StyleProfile: Sendable, Codable, Equatable {
    public var samples: [String]

    public init(samples: [String] = []) {
        self.samples = samples
    }
}

public struct ReplyRequest: Sendable, Equatable {
    public let context: CapturedContext
    public let intent: ReplyIntent
    public let tone: Tone
    public let style: StyleProfile

    public init(context: CapturedContext, intent: ReplyIntent, tone: Tone, style: StyleProfile) {
        self.context = context
        self.intent = intent
        self.tone = tone
        self.style = style
    }
}

public struct Prompt: Sendable, Equatable {
    public let system: String
    public let user: String
}

public struct ReplyCandidate: Sendable, Equatable, Codable {
    public enum Label: String, Sendable, Codable, CaseIterable {
        case short, standard, polite
    }

    public let label: Label
    public let text: String

    public init(label: Label, text: String) {
        self.label = label
        self.text = text
    }
}

public enum CandidateParserError: Error, Equatable {
    case noJSONFound
    case malformed(String)
    case wrongCandidateCount(Int)
}
