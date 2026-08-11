import Foundation

/// Account status as reported by `account/read`.
public struct CodexAccountStatus: Sendable, Equatable {
    public let isLoggedIn: Bool
    public let plan: String?

    public init(isLoggedIn: Bool, plan: String?) {
        self.isLoggedIn = isLoggedIn
        self.plan = plan
    }
}

public enum CodexClientError: Error, Equatable {
    case codexExecutableNotFound
    case notStarted
    case turnFailed(String)
}

/// Exact JSON-RPC method strings, derived from
/// `docs/reference/app-server-schema/{ClientRequest,ClientNotification,ServerNotification}.json`.
enum CodexMethod {
    static let initialize = "initialize"
    static let initialized = "initialized"
    static let threadStart = "thread/start"
    static let turnStart = "turn/start"
    static let accountRead = "account/read"

    static let agentMessageDelta = "item/agentMessage/delta"
    static let turnCompleted = "turn/completed"
    static let error = "error"

    static let commandExecutionRequestApproval = "item/commandExecution/requestApproval"
    static let fileChangeRequestApproval = "item/fileChange/requestApproval"
    static let applyPatchApproval = "applyPatchApproval"
    static let execCommandApproval = "execCommandApproval"
}

/// Parses the notification payloads this client cares about directly from `JSONValue`,
/// rather than round-tripping through Codable DTOs for the whole (huge) protocol surface.
enum CodexNotificationParser {
    struct AgentMessageDelta {
        let threadId: String
        let turnId: String
        let delta: String
    }

    static func agentMessageDelta(from params: JSONValue?) -> AgentMessageDelta? {
        guard
            case .string(let threadId)? = params?["threadId"],
            case .string(let turnId)? = params?["turnId"],
            case .string(let delta)? = params?["delta"]
        else { return nil }
        return AgentMessageDelta(threadId: threadId, turnId: turnId, delta: delta)
    }

    struct TurnCompleted {
        let threadId: String
        let turnId: String
    }

    static func turnCompleted(from params: JSONValue?) -> TurnCompleted? {
        guard
            case .string(let threadId)? = params?["threadId"],
            case .string(let turnId)? = params?["turn"]?["id"]
        else { return nil }
        return TurnCompleted(threadId: threadId, turnId: turnId)
    }

    struct TurnErrorInfo {
        let threadId: String
        let turnId: String
        let message: String
    }

    static func turnError(from params: JSONValue?) -> TurnErrorInfo? {
        guard
            case .string(let threadId)? = params?["threadId"],
            case .string(let turnId)? = params?["turnId"],
            case .string(let message)? = params?["error"]?["message"]
        else { return nil }
        return TurnErrorInfo(threadId: threadId, turnId: turnId, message: message)
    }
}

/// Maps `GetAccountResponse` JSON into `CodexAccountStatus`.
enum CodexAccountStatusMapper {
    static func map(_ response: JSONValue) -> CodexAccountStatus {
        guard let account = response["account"], account != .null else {
            return CodexAccountStatus(isLoggedIn: false, plan: nil)
        }
        guard case .string("chatgpt")? = account["type"] else {
            return CodexAccountStatus(isLoggedIn: true, plan: nil)
        }
        guard case .string(let planType)? = account["planType"] else {
            return CodexAccountStatus(isLoggedIn: true, plan: nil)
        }
        return CodexAccountStatus(isLoggedIn: true, plan: planType)
    }
}

/// We never execute commands or apply patches, so every server-initiated approval
/// request is rejected. Decision field names/values come from
/// `CommandExecutionRequestApprovalResponse.json`, `FileChangeRequestApprovalResponse.json`,
/// `ApplyPatchApprovalResponse.json`, and `ExecCommandApprovalResponse.json`.
enum CodexApprovalResponder {
    static func response(for method: String) -> Result<JSONValue, JSONRPCError>? {
        switch method {
        case CodexMethod.commandExecutionRequestApproval, CodexMethod.fileChangeRequestApproval:
            return .success(.object(["decision": .string("decline")]))
        case CodexMethod.applyPatchApproval, CodexMethod.execCommandApproval:
            return .success(.object(["decision": .string("denied")]))
        default:
            return nil
        }
    }
}
