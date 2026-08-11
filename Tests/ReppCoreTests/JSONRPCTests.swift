import Foundation
import Testing
@testable import ReppCore

@Suite struct JSONRPCConnectionTests {
    struct Greeting: Decodable, Equatable, Sendable {
        let message: String
    }

    @Test func requestSendsFrameAndResolvesOnMatchingResponse() async throws {
        let transport = InMemoryTransport()
        let connection = JSONRPCConnection(transport: transport)
        await connection.start()

        async let result: Greeting = connection.request(
            method: "hello",
            params: .object(["name": .string("codex")])
        )

        try await waitUntil { !transport.sentFrames.isEmpty }
        let sentFrame = transport.sentJSON(at: 0)
        #expect(sentFrame?["jsonrpc"] == .string("2.0"))
        #expect(sentFrame?["method"] == .string("hello"))
        #expect(sentFrame?["params"] == .object(["name": .string("codex")]))
        guard case .number(let idNumber)? = sentFrame?["id"] else {
            Issue.record("sent frame missing numeric id")
            return
        }

        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(idNumber),
            "result": .object(["message": .string("hi codex")]),
        ]))

        let value = try await result
        #expect(value == Greeting(message: "hi codex"))
    }

    @Test func concurrentRequestsResolveIndependentlyOutOfOrder() async throws {
        let transport = InMemoryTransport()
        let connection = JSONRPCConnection(transport: transport)
        await connection.start()

        async let first: JSONValue = connection.requestRaw(method: "a", params: nil)
        async let second: JSONValue = connection.requestRaw(method: "b", params: nil)

        try await waitUntil { transport.sentFrames.count >= 2 }

        func idFor(method: String) -> Double? {
            for index in 0..<transport.sentFrames.count {
                let frame = transport.sentJSON(at: index)
                if frame?["method"] == .string(method), case .number(let id)? = frame?["id"] {
                    return id
                }
            }
            return nil
        }

        let idForA = try #require(idFor(method: "a"))
        let idForB = try #require(idFor(method: "b"))

        // Respond out of order: b resolves before a.
        transport.deliver(.object(["jsonrpc": .string("2.0"), "id": .number(idForB), "result": .string("result-b")]))
        transport.deliver(.object(["jsonrpc": .string("2.0"), "id": .number(idForA), "result": .string("result-a")]))

        let resultA = try await first
        let resultB = try await second
        #expect(resultA == .string("result-a"))
        #expect(resultB == .string("result-b"))
    }

    @Test func errorResponseThrowsJSONRPCError() async throws {
        let transport = InMemoryTransport()
        let connection = JSONRPCConnection(transport: transport)
        await connection.start()

        async let result: JSONValue = connection.requestRaw(method: "boom", params: nil)
        try await waitUntil { !transport.sentFrames.isEmpty }
        guard case .number(let id)? = transport.sentJSON(at: 0)?["id"] else {
            Issue.record("sent frame missing numeric id")
            return
        }

        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(id),
            "error": .object(["code": .number(-32000), "message": .string("boom failed")]),
        ]))

        do {
            _ = try await result
            Issue.record("expected JSONRPCError to be thrown")
        } catch let error as JSONRPCError {
            #expect(error.code == -32000)
            #expect(error.message == "boom failed")
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test func serverNotificationAppearsInNotificationsStream() async throws {
        let transport = InMemoryTransport()
        let connection = JSONRPCConnection(transport: transport)
        var iterator = await connection.notifications.makeAsyncIterator()
        await connection.start()

        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "method": .string("thread/update"),
            "params": .object(["status": .string("running")]),
        ]))

        let received = await iterator.next()
        #expect(received == JSONRPCIncomingNotification(
            method: "thread/update",
            params: .object(["status": .string("running")])
        ))
    }

    @Test func serverRequestInvokesHandlerAndSendsResponseWithSameId() async throws {
        let transport = InMemoryTransport()
        let connection = JSONRPCConnection(transport: transport)
        await connection.setRequestHandler { method, _ in
            #expect(method == "approve")
            return .success(.object(["approved": .bool(true)]))
        }
        await connection.start()

        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(7),
            "method": .string("approve"),
            "params": .null,
        ]))

        try await waitUntil { !transport.sentFrames.isEmpty }
        let response = transport.sentJSON(at: 0)
        #expect(response?["id"] == .number(7))
        #expect(response?["result"] == .object(["approved": .bool(true)]))
    }

    @Test func serverRequestWithoutHandlerRespondsMethodNotFound() async throws {
        let transport = InMemoryTransport()
        let connection = JSONRPCConnection(transport: transport)
        await connection.start()

        transport.deliver(.object([
            "jsonrpc": .string("2.0"),
            "id": .number(3),
            "method": .string("unregistered"),
        ]))

        try await waitUntil { !transport.sentFrames.isEmpty }
        let response = transport.sentJSON(at: 0)
        #expect(response?["id"] == .number(3))
        guard case .object(let errorFields)? = response?["error"] else {
            Issue.record("expected error field in response")
            return
        }
        #expect(errorFields["code"] == .number(-32601))
    }

    @Test func closeFailsInFlightRequestWithConnectionClosed() async throws {
        let transport = InMemoryTransport()
        let connection = JSONRPCConnection(transport: transport)
        await connection.start()

        async let result: JSONValue = connection.requestRaw(method: "pending", params: nil)
        try await waitUntil { !transport.sentFrames.isEmpty }

        await connection.close()

        do {
            _ = try await result
            Issue.record("expected connectionClosed error")
        } catch let error as JSONRPCConnectionError {
            #expect(error == .connectionClosed)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test func requestAfterCloseThrowsConnectionClosedImmediately() async throws {
        let transport = InMemoryTransport()
        let connection = JSONRPCConnection(transport: transport)
        await connection.start()
        await connection.close()

        do {
            let _: JSONValue = try await connection.requestRaw(method: "x", params: nil)
            Issue.record("expected connectionClosed error")
        } catch let error as JSONRPCConnectionError {
            #expect(error == .connectionClosed)
        } catch {
            Issue.record("unexpected error type: \(error)")
        }
    }

    @Test func notifySendsFrameWithoutId() async throws {
        let transport = InMemoryTransport()
        let connection = JSONRPCConnection(transport: transport)
        await connection.start()

        try await connection.notify(method: "log", params: .object(["level": .string("info")]))

        try await waitUntil { !transport.sentFrames.isEmpty }
        let frame = transport.sentJSON(at: 0)
        #expect(frame?["method"] == .string("log"))
        #expect(frame?["id"] == nil)
    }

    @Test func malformedIncomingFramesAreSkippedSilently() async throws {
        let transport = InMemoryTransport()
        let connection = JSONRPCConnection(transport: transport)
        await connection.start()

        transport.deliverRaw(Data("not json".utf8))
        transport.deliverRaw(Data(#"{"foo":"bar"}"#.utf8))

        async let result: JSONValue = connection.requestRaw(method: "ping", params: nil)
        try await waitUntil { !transport.sentFrames.isEmpty }
        guard case .number(let id)? = transport.sentJSON(at: 0)?["id"] else {
            Issue.record("sent frame missing numeric id")
            return
        }
        transport.deliver(.object(["jsonrpc": .string("2.0"), "id": .number(id), "result": .string("pong")]))

        #expect(try await result == .string("pong"))
    }

    @Test func responseWithUnknownIdIsSkipped() async throws {
        let transport = InMemoryTransport()
        let connection = JSONRPCConnection(transport: transport)
        await connection.start()

        transport.deliver(.object(["jsonrpc": .string("2.0"), "id": .number(999), "result": .string("nobody-waiting")]))

        async let result: JSONValue = connection.requestRaw(method: "ping", params: nil)
        try await waitUntil { !transport.sentFrames.isEmpty }
        guard case .number(let id)? = transport.sentJSON(at: 0)?["id"] else {
            Issue.record("sent frame missing numeric id")
            return
        }
        transport.deliver(.object(["jsonrpc": .string("2.0"), "id": .number(id), "result": .string("pong")]))

        #expect(try await result == .string("pong"))
    }
}
