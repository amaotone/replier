import Foundation
import Testing
@testable import ReppCore

@Suite struct JSONValueTests {
    @Test func decodesPrimitiveTypes() throws {
        let json = Data("""
        {"n":null,"b":true,"i":1,"f":1.5,"s":"hi"}
        """.utf8)
        let value = try JSONDecoder().decode(JSONValue.self, from: json)
        #expect(value["n"] == .null)
        #expect(value["b"] == .bool(true))
        #expect(value["i"] == .number(1))
        #expect(value["f"] == .number(1.5))
        #expect(value["s"] == .string("hi"))
    }

    @Test func roundTripsNestedObjectAndArray() throws {
        let original: JSONValue = .object([
            "name": .string("codex"),
            "count": .number(3),
            "active": .bool(true),
            "tags": .array([.string("a"), .string("b")]),
            "nested": .object(["x": .number(1), "y": .null]),
        ])

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)

        #expect(decoded == original)
    }

    @Test func arraySubscriptReturnsElementOrNil() {
        let value: JSONValue = .array([.number(10), .number(20)])
        #expect(value[0] == .number(10))
        #expect(value[1] == .number(20))
        #expect(value[2] == nil)
    }

    @Test func objectSubscriptReturnsNilForMissingKey() {
        let value: JSONValue = .object(["a": .number(1)])
        #expect(value["missing"] == nil)
        #expect(value["a"] == .number(1))
    }
}
