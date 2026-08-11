import Foundation
import Testing
@testable import ReppCore

@Suite struct ProcessTransportTests {
    @Test func echoesFrameThroughCat() async throws {
        let transport = try ProcessTransport(executableURL: URL(fileURLWithPath: "/bin/cat"), arguments: [])

        let payload = JSONValue.object([
            "jsonrpc": .string("2.0"),
            "id": .number(1),
            "method": .string("ping"),
        ])
        let data = try JSONEncoder().encode(payload)

        try await transport.send(data)

        let stream = transport.incoming
        struct TimedOut: Error {}
        let received = try await withThrowingTaskGroup(of: Data.self) { group -> Data in
            group.addTask {
                for await frame in stream {
                    return frame
                }
                throw TimedOut()
            }
            group.addTask {
                try await Task.sleep(for: .seconds(5))
                throw TimedOut()
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw TimedOut() }
            return first
        }

        #expect(received == data)
        await transport.close()
    }
}
