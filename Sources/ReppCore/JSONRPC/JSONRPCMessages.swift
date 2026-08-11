import Foundation

public struct JSONRPCError: Error, Sendable, Equatable {
    public let code: Int
    public let message: String
    public let data: JSONValue?

    public init(code: Int, message: String, data: JSONValue? = nil) {
        self.code = code
        self.message = message
        self.data = data
    }
}

public enum JSONRPCConnectionError: Error, Equatable {
    case connectionClosed
    case invalidResponse(String)
}

public struct JSONRPCIncomingNotification: Sendable, Equatable {
    public let method: String
    public let params: JSONValue?

    public init(method: String, params: JSONValue?) {
        self.method = method
        self.params = params
    }
}

enum JSONRPCStatusCode {
    static let methodNotFound = -32601
}

extension JSONRPCError {
    var jsonValue: JSONValue {
        var fields: [String: JSONValue] = [
            "code": .number(Double(code)),
            "message": .string(message),
        ]
        if let data { fields["data"] = data }
        return .object(fields)
    }
}

/// Parsed shape of a raw incoming frame, independent of the transport.
enum JSONRPCIncomingFrame {
    case response(id: Int, result: JSONValue?, error: JSONRPCError?)
    case notification(method: String, params: JSONValue?)
    case serverRequest(id: JSONValue, method: String, params: JSONValue?)
    case malformed

    static func parse(_ data: Data) -> JSONRPCIncomingFrame {
        guard
            let value = try? JSONDecoder().decode(JSONValue.self, from: data),
            case .object(let fields) = value
        else {
            return .malformed
        }

        let methodString: String? = {
            if case .string(let method)? = fields["method"] { return method }
            return nil
        }()
        let idField = fields["id"]
        let params = fields["params"]

        if let methodString {
            if let idField {
                return .serverRequest(id: idField, method: methodString, params: params)
            }
            return .notification(method: methodString, params: params)
        }

        guard case .number(let idNumber)? = idField else {
            return .malformed
        }
        let id = Int(idNumber)

        if let errorField = fields["error"] {
            guard
                case .object(let errorFields) = errorField,
                case .string(let message)? = errorFields["message"],
                case .number(let codeNumber)? = errorFields["code"]
            else {
                return .malformed
            }
            let error = JSONRPCError(code: Int(codeNumber), message: message, data: errorFields["data"])
            return .response(id: id, result: nil, error: error)
        }

        if let resultField = fields["result"] {
            return .response(id: id, result: resultField, error: nil)
        }

        return .malformed
    }
}

enum JSONRPCFrameBuilder {
    static func request(id: Int, method: String, params: JSONValue?) -> JSONValue {
        var fields: [String: JSONValue] = [
            "jsonrpc": .string("2.0"),
            "id": .number(Double(id)),
            "method": .string(method),
        ]
        if let params { fields["params"] = params }
        return .object(fields)
    }

    static func notification(method: String, params: JSONValue?) -> JSONValue {
        var fields: [String: JSONValue] = [
            "jsonrpc": .string("2.0"),
            "method": .string(method),
        ]
        if let params { fields["params"] = params }
        return .object(fields)
    }

    static func response(id: JSONValue, result: JSONValue) -> JSONValue {
        .object(["jsonrpc": .string("2.0"), "id": id, "result": result])
    }

    static func errorResponse(id: JSONValue, error: JSONRPCError) -> JSONValue {
        .object(["jsonrpc": .string("2.0"), "id": id, "error": error.jsonValue])
    }
}
