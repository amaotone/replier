import Foundation

/// Locates the `codex` CLI executable.
///
/// A `.app` launched from Finder inherits a minimal PATH
/// (`/usr/bin:/bin:/usr/sbin:/sbin`), not the user's interactive shell PATH, so `codex`
/// installed via Homebrew or (especially) a Node version manager like mise/volta/nvm is
/// invisible to a naive `which codex` shell-out. This type widens the search: a static
/// list of well-known install locations (checked directly, no shell involved) first,
/// then — only if nothing hit — a handful of shell/version-manager probes, each
/// time-boxed so a hung or misbehaving shell can never freeze the app.
public struct CodexExecutableLocator: Sendable {

    /// Ordered candidate paths to probe under `home`, before any shell fallback runs.
    /// Order matters: stable shims/symlinks come first so a Node version bump doesn't
    /// silently stop resolving `codex` (a version-pinned path like
    /// `.nvm/versions/node/v20.11.0/bin/codex` breaks the moment that version is
    /// removed; `.local/share/mise/shims/codex` does not).
    public static func candidatePaths(home: URL) -> [URL] {
        var candidates: [URL] = [
            home.appendingPathComponent(".local/share/mise/shims/codex"),
            // Created by `curl https://chatgpt.com/codex/install.sh | sh` (the
            // "standalone" managed install documented in codex's app-server-daemon
            // README); `current` is a stable symlink the installer repoints on
            // update, so — like the mise shim above — it survives version bumps.
            home.appendingPathComponent(".codex/packages/standalone/current/codex"),
            home.appendingPathComponent(".local/bin/codex"),
            URL(fileURLWithPath: "/opt/homebrew/bin/codex"),
            URL(fileURLWithPath: "/usr/local/bin/codex"),
            // The ChatGPT desktop app bundles its own `codex` binary at a fixed,
            // PATH-independent location (verified: 265MB, `codex-cli
            // 0.145.0-alpha.27`) — a rock-solid fallback for anyone who has the
            // desktop app installed but never separately installed the CLI. Checked
            // after the user's own installs (which are usually newer and are what
            // the user would expect to run) but before the deeper version-manager
            // globs below.
            URL(fileURLWithPath: "/Applications/ChatGPT.app/Contents/Resources/codex"),
            home.appendingPathComponent("Applications/ChatGPT.app/Contents/Resources/codex"),
            home.appendingPathComponent(".volta/bin/codex"),
            home.appendingPathComponent(".npm-global/bin/codex"),
        ]
        candidates.append(contentsOf: nvmCandidates(home: home))
        candidates.append(home.appendingPathComponent(".fnm/aliases/default/bin/codex"))
        candidates.append(home.appendingPathComponent("Library/pnpm/codex"))
        candidates.append(home.appendingPathComponent(".bun/bin/codex"))
        return candidates
    }

    /// `~/.nvm/versions/node/*/bin/codex`, newest node version first: an nvm install
    /// with several node versions present should prefer whichever `codex` was
    /// installed under the newest one, since that's the version most likely still in
    /// active use. Versions are directory names like `v20.11.0`; parsed and compared
    /// numerically (falling back to a lexicographic tiebreak) rather than sorted as
    /// plain strings, since e.g. `"v9"` would otherwise sort after `"v10"`.
    private static func nvmCandidates(home: URL) -> [URL] {
        let versionsDir = home.appendingPathComponent(".nvm/versions/node")
        guard
            let entries = try? FileManager.default.contentsOfDirectory(
                at: versionsDir,
                includingPropertiesForKeys: nil
            )
        else { return [] }
        let sorted = entries.sorted { newestNodeVersionFirst($0.lastPathComponent, $1.lastPathComponent) }
        return sorted.map { $0.appendingPathComponent("bin/codex") }
    }

    private static func newestNodeVersionFirst(_ lhs: String, _ rhs: String) -> Bool {
        func components(_ name: String) -> [Int] {
            let trimmed = name.hasPrefix("v") ? String(name.dropFirst()) : name
            return trimmed.split(separator: ".").compactMap { Int($0) }
        }
        let lhsComponents = components(lhs)
        let rhsComponents = components(rhs)
        for (a, b) in zip(lhsComponents, rhsComponents) where a != b {
            return a > b
        }
        if lhsComponents.count != rhsComponents.count {
            return lhsComponents.count > rhsComponents.count
        }
        return lhs > rhs
    }

    /// Returns the first candidate `isExecutable` accepts, or `nil` if none match.
    /// Pure aside from the injected predicate: order of `candidates` is respected
    /// exactly, so callers control priority entirely via list order.
    public static func firstExecutable(
        in candidates: [URL],
        isExecutable: (URL) -> Bool = { FileManager.default.isExecutableFile(atPath: $0.path) }
    ) -> URL? {
        candidates.first(where: isExecutable)
    }

    /// A user-supplied override is used only if it still points at a real executable
    /// file; a stale or mistyped override (e.g. the app was moved, or a version
    /// manager's install layout changed) falls back to normal discovery rather than
    /// hard-failing. Pure aside from the injected predicate — kept separate from
    /// `locate` so this fallthrough behavior is directly unit-testable without
    /// touching the filesystem or spawning a shell.
    static func resolveOverride(
        _ overridePath: String?,
        isExecutable: (URL) -> Bool = { FileManager.default.isExecutableFile(atPath: $0.path) }
    ) -> URL? {
        guard let overridePath, !overridePath.isEmpty else { return nil }
        let url = URL(fileURLWithPath: overridePath)
        return isExecutable(url) ? url : nil
    }

    /// Full resolution: user override, then the static candidate list, then (only if
    /// both come up empty) a handful of shell/version-manager probes. Each probe is
    /// wall-clock timeboxed to 5s with stderr suppressed, so a hung or noisy shell
    /// config can't freeze the app — see `runWithTimeout`.
    public static func locate(overridePath: String? = nil) -> URL? {
        if let override = resolveOverride(overridePath) {
            return override
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        if let found = firstExecutable(in: candidatePaths(home: home)) {
            return found
        }

        return shellFallback(home: home)
    }

    // MARK: - Shell / version-manager fallbacks (impure; only reached when the static
    // candidate list above misses entirely)

    private static func shellFallback(home: URL) -> URL? {
        if let found = loginShellCodexPath() {
            return found
        }
        if let found = versionManagerWhichCodex(toolCandidates: miseCandidates(home: home)) {
            return found
        }
        if let found = versionManagerWhichCodex(toolCandidates: voltaCandidates(home: home)) {
            return found
        }
        return posixShellCodexPath()
    }

    /// a. The user's login shell, run as an interactive login shell so any config that
    /// activates a version manager (mise `activate`, volta's PATH injection, nvm's
    /// `.bashrc`/`.zshrc` sourcing, fish's `conf.d`, …) actually runs — plain
    /// `sh -lc` only sources `/etc/profile` and misses all of that.
    private static func loginShellCodexPath() -> URL? {
        let shell = loginShellPath()
        guard
            let output = runWithTimeout(executable: URL(fileURLWithPath: shell), arguments: ["-l", "-i", "-c", "command -v codex"])
        else { return nil }
        return executableFromShellOutput(output)
    }

    /// `dscl` reads the account record directly (no shell involved), so it reflects
    /// the shell configured in System Settings even when `$SHELL` in our own inherited
    /// environment doesn't match (e.g. we were spawned by launchd, not a login shell).
    private static func loginShellPath() -> String {
        if
            let dsclOutput = runWithTimeout(
                executable: URL(fileURLWithPath: "/usr/bin/dscl"),
                arguments: [".", "-read", "/Users/\(NSUserName())", "UserShell"]
            ),
            let colonRange = dsclOutput.range(of: "UserShell:")
        {
            let shell = dsclOutput[colonRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !shell.isEmpty { return shell }
        }
        if let shellEnv = ProcessInfo.processInfo.environment["SHELL"], !shellEnv.isEmpty {
            return shellEnv
        }
        return "/bin/zsh"
    }

    /// b. Delegates to the version manager's own resolution (`mise which codex`,
    /// `volta which codex`) rather than re-deriving PATH manipulation ourselves —
    /// each tool knows its own shim/activation layout best.
    private static func versionManagerWhichCodex(toolCandidates: [URL]) -> URL? {
        for tool in toolCandidates where FileManager.default.isExecutableFile(atPath: tool.path) {
            guard let output = runWithTimeout(executable: tool, arguments: ["which", "codex"]) else { continue }
            if let found = executableFromShellOutput(output) {
                return found
            }
        }
        return nil
    }

    private static func miseCandidates(home: URL) -> [URL] {
        [
            home.appendingPathComponent(".local/bin/mise"),
            URL(fileURLWithPath: "/opt/homebrew/bin/mise"),
        ]
    }

    private static func voltaCandidates(home: URL) -> [URL] {
        [
            home.appendingPathComponent(".volta/bin/volta"),
            URL(fileURLWithPath: "/opt/homebrew/bin/volta"),
            URL(fileURLWithPath: "/usr/local/bin/volta"),
        ]
    }

    /// c. Last resort: mirrors the previous (pre-fix) behavior so nothing regresses
    /// for setups where `/etc/profile` alone was already sufficient.
    private static func posixShellCodexPath() -> URL? {
        guard
            let output = runWithTimeout(executable: URL(fileURLWithPath: "/bin/sh"), arguments: ["-lc", "command -v codex"])
        else { return nil }
        return executableFromShellOutput(output)
    }

    /// Turns a shell's stdout line into a usable executable URL. Deliberately does
    /// *not* resolve symlinks when that would change the invoked filename away from
    /// `codex`: mise's shims are themselves symlinks (to the `mise` binary), which
    /// dispatch based on the *invoked path's filename* — following the symlink would
    /// hand back `.../mise` and silently break execution (verified against a real
    /// mise install). Resolving is safe, and done for tidiness, whenever the target's
    /// filename is still `codex` (e.g. Homebrew's Cellar symlinks).
    private static func executableFromShellOutput(_ output: String) -> URL? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let url = URL(fileURLWithPath: trimmed)
        guard FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
        let resolved = url.resolvingSymlinksInPath()
        return resolved.lastPathComponent == "codex" ? resolved : url
    }

    // MARK: - Timeboxed process execution

    /// Runs `executable` with `arguments`, waiting up to `timeout` seconds on a
    /// background queue. On timeout, `terminate()`s the process and returns `nil`
    /// rather than blocking the caller indefinitely — an interactive login shell can
    /// hang (e.g. waiting on a broken plugin, or a TTY it doesn't have), and this must
    /// never freeze the app. stderr is discarded entirely (`/dev/null`) so a noisy
    /// shell config can't fill an unread pipe and deadlock the child instead.
    private static func runWithTimeout(
        executable: URL,
        arguments: [String],
        timeout: TimeInterval = 5
    ) -> String? {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            semaphore.signal()
        }

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            process.terminate()
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
