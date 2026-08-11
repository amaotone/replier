import Foundation

/// A `JSONRPCTransport` that speaks newline-delimited JSON over the stdio of a
/// child process (e.g. `codex app-server`).
public final class ProcessTransport: JSONRPCTransport, @unchecked Sendable {
    private let process: Process
    private let stdinHandle: FileHandle
    private let lock = NSLock()
    private var isClosed = false

    public let incoming: AsyncStream<Data>
    private let continuation: AsyncStream<Data>.Continuation

    public init(executableURL: URL, arguments: [String]) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe

        self.process = process
        self.stdinHandle = stdinPipe.fileHandleForWriting

        var streamContinuation: AsyncStream<Data>.Continuation!
        self.incoming = AsyncStream { streamContinuation = $0 }
        self.continuation = streamContinuation

        try process.run()

        let stdoutHandle = stdoutPipe.fileHandleForReading
        let continuation = streamContinuation!
        Task {
            do {
                for try await line in stdoutHandle.bytes.lines {
                    if line.isEmpty { continue }
                    continuation.yield(Data(line.utf8))
                }
            } catch {
                // stdout closed or errored; fall through and finish the stream.
            }
            continuation.finish()
        }
    }

    public func send(_ frame: Data) async throws {
        var payload = frame
        payload.append(0x0A)
        try stdinHandle.write(contentsOf: payload)
    }

    public func close() async {
        let alreadyClosed = lock.withLock {
            let wasClosed = isClosed
            isClosed = true
            return wasClosed
        }
        guard !alreadyClosed else { return }

        continuation.finish()
        if process.isRunning {
            process.terminate()
        }
        try? stdinHandle.close()
    }
}
