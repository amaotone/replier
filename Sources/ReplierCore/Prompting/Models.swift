public enum SourceApp: String, Sendable, Codable, Equatable {
    case slack, mail, browser, other
}

/// Where the reply will be sent, chosen by the user in the panel (defaulted from
/// `SourceApp` at capture time, but independently editable — see `PanelModel.situation`).
public enum Situation: String, Sendable, Codable, CaseIterable {
    case mail, chat
}

public struct CapturedContext: Sendable, Equatable {
    public let text: String
    public let sourceApp: SourceApp

    public init(text: String, sourceApp: SourceApp) {
        self.text = text
        self.sourceApp = sourceApp
    }
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
    /// The user's one-line gist/instruction for what the reply should say.
    public let gist: String
    public let tone: Tone
    public let situation: Situation
    public let style: StyleProfile

    public init(context: CapturedContext, gist: String, tone: Tone, situation: Situation, style: StyleProfile) {
        self.context = context
        self.gist = gist
        self.tone = tone
        self.situation = situation
        self.style = style
    }
}

public struct Prompt: Sendable, Equatable {
    public let system: String
    public let user: String
}

public struct ReplyCandidate: Sendable, Equatable, Codable {
    public enum Label: String, Sendable, Codable, CaseIterable {
        case short, long
    }

    public let label: Label
    public let text: String

    public init(label: Label, text: String) {
        self.label = label
        self.text = text
    }
}
