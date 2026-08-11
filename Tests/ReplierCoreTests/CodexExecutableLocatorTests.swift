import Foundation
import Testing
@testable import ReplierCore

@Suite struct CodexExecutableLocatorTests {
    private let fakeHome = URL(fileURLWithPath: "/Users/fake-user")

    // MARK: - candidatePaths

    @Test func candidatePathsIncludesMiseShimHomebrewAndVoltaExpandedAgainstHome() {
        let candidates = CodexExecutableLocator.candidatePaths(home: fakeHome)

        #expect(candidates.contains(fakeHome.appendingPathComponent(".local/share/mise/shims/codex")))
        #expect(candidates.contains(fakeHome.appendingPathComponent(".local/bin/codex")))
        #expect(candidates.contains(URL(fileURLWithPath: "/opt/homebrew/bin/codex")))
        #expect(candidates.contains(URL(fileURLWithPath: "/usr/local/bin/codex")))
        #expect(candidates.contains(fakeHome.appendingPathComponent(".volta/bin/codex")))
        #expect(candidates.contains(fakeHome.appendingPathComponent(".npm-global/bin/codex")))
        #expect(candidates.contains(fakeHome.appendingPathComponent(".fnm/aliases/default/bin/codex")))
        #expect(candidates.contains(fakeHome.appendingPathComponent("Library/pnpm/codex")))
        #expect(candidates.contains(fakeHome.appendingPathComponent(".bun/bin/codex")))
    }

    @Test func candidatePathsOrdersMiseShimBeforeHomebrewBeforeVolta() {
        let candidates = CodexExecutableLocator.candidatePaths(home: fakeHome)

        let miseIndex = candidates.firstIndex(of: fakeHome.appendingPathComponent(".local/share/mise/shims/codex"))
        let homebrewIndex = candidates.firstIndex(of: URL(fileURLWithPath: "/opt/homebrew/bin/codex"))
        let voltaIndex = candidates.firstIndex(of: fakeHome.appendingPathComponent(".volta/bin/codex"))

        #expect(miseIndex != nil && homebrewIndex != nil && voltaIndex != nil)
        #expect(miseIndex! < homebrewIndex!)
        #expect(homebrewIndex! < voltaIndex!)
    }

    @Test func candidatePathsIncludesChatGPTAppBundledCodexAndStandaloneManagedInstall() {
        let candidates = CodexExecutableLocator.candidatePaths(home: fakeHome)

        #expect(candidates.contains(URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex")))
        #expect(
            candidates.contains(
                fakeHome.appendingPathComponent("Applications/ChatGPT.app/Contents/Resources/codex")
            )
        )
        #expect(candidates.contains(fakeHome.appendingPathComponent(".codex/packages/standalone/current/codex")))
    }

    @Test func candidatePathsOrdersMiseShimAndHomebrewBeforeChatGPTAppBundledCodex() {
        let candidates = CodexExecutableLocator.candidatePaths(home: fakeHome)

        let miseIndex = candidates.firstIndex(of: fakeHome.appendingPathComponent(".local/share/mise/shims/codex"))
        let homebrewIndex = candidates.firstIndex(of: URL(fileURLWithPath: "/opt/homebrew/bin/codex"))
        let chatGPTAppIndex = candidates.firstIndex(
            of: URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex")
        )
        let voltaIndex = candidates.firstIndex(of: fakeHome.appendingPathComponent(".volta/bin/codex"))

        #expect(miseIndex != nil && homebrewIndex != nil && chatGPTAppIndex != nil && voltaIndex != nil)
        #expect(miseIndex! < chatGPTAppIndex!)
        #expect(homebrewIndex! < chatGPTAppIndex!)
        #expect(chatGPTAppIndex! < voltaIndex!)
    }

    @Test func candidatePathsEnumeratesNvmVersionsNewestFirst() throws {
        let tempHome = try makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempHome) }

        let nvmVersionsDir = tempHome.appendingPathComponent(".nvm/versions/node")
        for version in ["v18.20.4", "v20.11.0", "v9.11.2", "v20.2.0"] {
            try FileManager.default.createDirectory(
                at: nvmVersionsDir.appendingPathComponent(version).appendingPathComponent("bin"),
                withIntermediateDirectories: true
            )
        }

        let candidates = CodexExecutableLocator.candidatePaths(home: tempHome)
        // Each nvm candidate ends in `.../<version>/bin/codex`; compare just the
        // version component the ordering is actually about, rather than full URL
        // equality — the temp directory's absolute prefix can be canonicalized
        // differently between `FileManager.contentsOfDirectory` and a path built by
        // hand (e.g. `/var/folders/...` vs. `/private/var/folders/...`), which is
        // incidental to this test and not what it means to verify.
        let nvmVersionsInOrder = candidates
            .filter { $0.path.contains("/.nvm/versions/node/") }
            .map { $0.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent }

        // Newest first, and compared numerically (not lexicographically — "v9" must not
        // sort after "v20" the way plain string comparison would put it).
        #expect(nvmVersionsInOrder == ["v20.11.0", "v20.2.0", "v18.20.4", "v9.11.2"])
    }

    @Test func candidatePathsSkipsNvmEntirelyWhenDirectoryIsMissing() {
        let candidates = CodexExecutableLocator.candidatePaths(home: fakeHome)
        #expect(!candidates.contains { $0.path.contains("/.nvm/") })
    }

    // MARK: - firstExecutable

    @Test func firstExecutableReturnsFirstMatchAccordingToStubPredicate() {
        let a = URL(fileURLWithPath: "/fake/a/codex")
        let b = URL(fileURLWithPath: "/fake/b/codex")
        let c = URL(fileURLWithPath: "/fake/c/codex")

        let found = CodexExecutableLocator.firstExecutable(in: [a, b, c]) { $0 == b || $0 == c }

        #expect(found == b)
    }

    @Test func firstExecutableReturnsNilWhenNoCandidateMatches() {
        let a = URL(fileURLWithPath: "/fake/a/codex")
        let b = URL(fileURLWithPath: "/fake/b/codex")

        let found = CodexExecutableLocator.firstExecutable(in: [a, b]) { _ in false }

        #expect(found == nil)
    }

    @Test func firstExecutableRespectsCandidateOrderMiseShimBeforeHomebrew() {
        let miseShim = URL(fileURLWithPath: "/fake/.local/share/mise/shims/codex")
        let homebrew = URL(fileURLWithPath: "/opt/homebrew/bin/codex")

        // Both "exist" per the stub predicate; list order alone must decide the winner.
        let found = CodexExecutableLocator.firstExecutable(in: [miseShim, homebrew]) { _ in true }
        #expect(found == miseShim)

        let foundReversed = CodexExecutableLocator.firstExecutable(in: [homebrew, miseShim]) { _ in true }
        #expect(foundReversed == homebrew)
    }

    @Test func firstExecutableOnEmptyCandidateListReturnsNil() {
        #expect(CodexExecutableLocator.firstExecutable(in: []) { _ in true } == nil)
    }

    // MARK: - override handling (pure: `resolveOverride`)

    @Test func resolveOverrideReturnsTheOverrideWhenItPointsAtARealExecutable() throws {
        let tempExecutable = try makeTempExecutable()
        defer { try? FileManager.default.removeItem(at: tempExecutable) }

        let resolved = CodexExecutableLocator.resolveOverride(tempExecutable.path)

        #expect(resolved == tempExecutable)
    }

    @Test func resolveOverrideFallsThroughOnNonexistentPath() {
        let resolved = CodexExecutableLocator.resolveOverride("/nonexistent/path/to/codex")
        #expect(resolved == nil)
    }

    @Test func resolveOverrideFallsThroughOnNilOrEmptyPath() {
        #expect(CodexExecutableLocator.resolveOverride(nil) == nil)
        #expect(CodexExecutableLocator.resolveOverride("") == nil)
    }

    @Test func resolveOverrideUsesInjectedPredicateRatherThanTouchingRealFilesystem() {
        let fakePath = "/fake/somewhere/codex"
        let resolved = CodexExecutableLocator.resolveOverride(fakePath) { $0.path == fakePath }
        #expect(resolved == URL(fileURLWithPath: fakePath))
    }

    // MARK: - locate(overridePath:) end-to-end for the override-hit path (no shell probes reached)

    @Test func locateReturnsOverrideDirectlyWithoutConsultingCandidatesWhenOverrideIsValid() throws {
        let tempExecutable = try makeTempExecutable()
        defer { try? FileManager.default.removeItem(at: tempExecutable) }

        let resolved = CodexExecutableLocator.locate(overridePath: tempExecutable.path)

        #expect(resolved == tempExecutable)
    }

    // MARK: - helpers

    /// Resolves symlinks on the created directory before returning: `FileManager
    /// .default.temporaryDirectory` on macOS is `/var/folders/...`, a symlink to
    /// `/private/var/folders/...`, but `contentsOfDirectory(at:)` (used by
    /// `nvmCandidates`) returns the canonicalized `/private/...` form — without this,
    /// path-equality assertions in tests that enumerate a temp directory would fail on
    /// a spurious `/var` vs. `/private/var` prefix mismatch, not an actual bug.
    private func makeTempDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.resolvingSymlinksInPath()
    }

    private func makeTempExecutable() throws -> URL {
        let dir = try makeTempDirectory()
        let file = dir.appendingPathComponent("codex")
        FileManager.default.createFile(atPath: file.path, contents: Data("#!/bin/sh\n".utf8))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: file.path)
        return file
    }
}

/// Live end-to-end resolution against the real machine, gated so it never runs in CI.
/// Run with: env -i HOME="$HOME" PATH=/usr/bin:/bin:/usr/sbin:/sbin REPLIER_LOCATOR_LIVE=1 swift test --filter liveResolution
@Test(.enabled(if: ProcessInfo.processInfo.environment["REPLIER_LOCATOR_LIVE"] == "1"))
func liveResolutionFindsCodexUnderMinimalPath() throws {
    let resolved = CodexExecutableLocator.locate(overridePath: nil)
    print("LIVE-RESOLVED: \(resolved?.path ?? "nil")")
    print("LIVE-PATH-ENV: \(ProcessInfo.processInfo.environment["PATH"] ?? "unset")")
    #expect(resolved != nil)
}
