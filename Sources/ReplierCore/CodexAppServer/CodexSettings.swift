import Foundation

/// User-configurable Codex generation settings. Persisted to `UserDefaults` and read
/// fresh on every draft (see `CodexReplyDrafter.draft`) so changes made in onboarding
/// take effect on the next reply without an app restart.
public enum CodexSettings {
    public static let modelDefaultsKey = "codexModel"
    public static let reasoningEffortDefaultsKey = "codexReasoningEffort"

    public static let defaultModel = "gpt-5.6-luna"
    public static let defaultReasoningEffort = "xhigh"

    /// `TurnStartParams.effort` (see `docs/reference/app-server-schema/v2/TurnStartParams.json`)
    /// types `ReasoningEffort` as a non-empty, model-advertised string rather than a fixed
    /// enum, so this list is a UI convenience covering the values Codex/GPT-5.x models
    /// commonly support, not a protocol-level constraint.
    public static let reasoningEffortOptions = ["minimal", "low", "medium", "high", "xhigh"]

    public static func currentModel(in defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: modelDefaultsKey) ?? defaultModel
    }

    public static func currentReasoningEffort(in defaults: UserDefaults = .standard) -> String {
        defaults.string(forKey: reasoningEffortDefaultsKey) ?? defaultReasoningEffort
    }
}
