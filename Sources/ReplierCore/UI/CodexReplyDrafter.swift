import Foundation

/// Wraps a `CodexAppServerClient` to satisfy `ReplyDrafting`: locates the `codex`
/// executable once at construction time, and lazily starts the underlying JSON-RPC
/// connection on first `draft` call (subsequent calls are cheap no-ops, guarded by
/// `CodexAppServerClient.start()`'s own actor-serialized `connection == nil` check).
public final class CodexReplyDrafter: ReplyDrafting {
    public enum DrafterError: Error, Equatable, CustomStringConvertible {
        case codexNotFound

        public var description: String {
            switch self {
            case .codexNotFound:
                return "Codexの実行ファイルが見つかりませんでした。`brew install codex` でインストールしてください。"
            }
        }
    }

    private let client: CodexAppServerClient?
    private let promptBuilder = PromptBuilder()
    // UserDefaults is thread-safe but predates Sendable annotations in this SDK.
    private nonisolated(unsafe) let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.client = CodexAppServerClient.locateExecutable().map(CodexAppServerClient.init(executableURL:))
        self.userDefaults = userDefaults
    }

    /// Test-only entry point: injects a pre-built client (e.g. one backed by
    /// `InMemoryTransport`), or `nil` to exercise the not-found path.
    init(client: CodexAppServerClient?, userDefaults: UserDefaults = .standard) {
        self.client = client
        self.userDefaults = userDefaults
    }

    public func draft(_ request: ReplyRequest) async throws -> AsyncThrowingStream<String, Error> {
        guard let client else {
            throw DrafterError.codexNotFound
        }
        try await client.start()
        return try await client.draftReplies(
            promptBuilder.build(request),
            model: CodexSettings.currentModel(in: userDefaults),
            effort: CodexSettings.currentReasoningEffort(in: userDefaults)
        )
    }
}
