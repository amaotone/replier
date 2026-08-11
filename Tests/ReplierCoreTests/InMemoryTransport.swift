import Foundation
@testable import ReplierCore

/// Test double for `JSONRPCTransport`. Records sent frames and lets tests
/// inject frames as if they arrived from the peer.
final class InMemoryTransport: JSONRPCTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var _sentFrames: [Data] = []
    private var _isClosed = false

    let incoming: AsyncStream<Data>
    private let continuation: AsyncStream<Data>.Continuation

    init() {
        var continuation: AsyncStream<Data>.Continuation!
        self.incoming = AsyncStream { continuation = $0 }
        self.continuation = continuation
    }

    var sentFrames: [Data] {
        lock.withLock { _sentFrames }
    }

    var isClosed: Bool {
        lock.withLock { _isClosed }
    }

    func send(_ frame: Data) async throws {
        lock.withLock { _sentFrames.append(frame) }
    }

    func close() async {
        lock.withLock { _isClosed = true }
        continuation.finish()
    }

    /// Simulates the peer sending `value` to us.
    func deliver(_ value: JSONValue) {
        continuation.yield((try? JSONEncoder().encode(value)) ?? Data())
    }

    func deliverRaw(_ data: Data) {
        continuation.yield(data)
    }

    func sentJSON(at index: Int) -> JSONValue? {
        let frames = sentFrames
        guard frames.indices.contains(index) else { return nil }
        return try? JSONDecoder().decode(JSONValue.self, from: frames[index])
    }
}

/// Polls `condition` until it is true or `timeout` elapses.
func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + timeout
    while !condition() {
        if ContinuousClock.now >= deadline {
            struct TimedOut: Error {}
            throw TimedOut()
        }
        try await Task.sleep(for: .milliseconds(5))
    }
}
