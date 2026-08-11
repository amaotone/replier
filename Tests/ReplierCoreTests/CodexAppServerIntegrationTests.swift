import Foundation
import Testing
@testable import ReplierCore

/// Exercises the real `codex app-server` binary. Only runs when explicitly opted in, since it
/// requires a working codex install and an authenticated account:
///
///   REPLIER_CODEX_INTEGRATION=1 swift test --filter CodexAppServerIntegration
@Suite struct CodexAppServerIntegrationTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["REPLIER_CODEX_INTEGRATION"] == "1"))
    func locateStartAccountStatusAndDraftRoundTrip() async throws {
        guard let executableURL = CodexAppServerClient.locateExecutable() else {
            Issue.record("codex executable not found on this machine")
            return
        }

        let client = CodexAppServerClient(executableURL: executableURL)
        try await client.start()

        let status = try await client.accountStatus()
        #expect(status.isLoggedIn)

        let prompt = Prompt(
            system: "You are a terse assistant. Reply with a single short sentence and nothing else.",
            user: "Say hello in one short sentence."
        )
        let stream = try await client.draftReplies(prompt)

        var collected = ""
        for try await chunk in stream {
            collected += chunk
        }
        #expect(!collected.isEmpty)

        await client.shutdown()
    }
}
