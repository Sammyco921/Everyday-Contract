import Foundation

public enum RequestPayload: Codable, Hashable, Sendable {
    case query(QueryRequest)
    case command(CommandRequest)
    case synchronize(SynchronizationRequest)

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case value
    }

    private enum Kind: String, Codable, Sendable {
        case query
        case command
        case synchronize
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "RequestPayload")
        switch try container.decode(Kind.self, forKey: .kind) {
        case .query: self = .query(try container.decode(QueryRequest.self, forKey: .value))
        case .command: self = .command(try container.decode(CommandRequest.self, forKey: .value))
        case .synchronize: self = .synchronize(try container.decode(SynchronizationRequest.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .query(value):
            try container.encode(Kind.query, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .command(value):
            try container.encode(Kind.command, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .synchronize(value):
            try container.encode(Kind.synchronize, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}

public struct ConversationPageRequest: Codable, Hashable, Sendable {
    public let conversationID: ConversationID
    public let after: ConversationMessageID?
    public let limit: UInt32

    public init(conversationID: ConversationID, after: ConversationMessageID? = nil, limit: UInt32) {
        self.conversationID = conversationID
        self.after = after
        self.limit = limit
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case conversationID
        case after
        case limit
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ConversationPageRequest")
        self.init(
            conversationID: try container.decode(ConversationID.self, forKey: .conversationID),
            after: try container.decodeIfPresent(ConversationMessageID.self, forKey: .after),
            limit: try container.decode(UInt32.self, forKey: .limit)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(conversationID, forKey: .conversationID)
        try container.encodeIfPresent(after, forKey: .after)
        try container.encode(limit, forKey: .limit)
    }
}

public struct ContentReferenceRequest: Codable, Hashable, Sendable {
    public let contentReferenceID: ContentReferenceID
    public let objectiveID: ObjectiveID?

    public init(contentReferenceID: ContentReferenceID, objectiveID: ObjectiveID? = nil) {
        self.contentReferenceID = contentReferenceID
        self.objectiveID = objectiveID
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case contentReferenceID
        case objectiveID
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ContentReferenceRequest")
        self.init(
            contentReferenceID: try container.decode(ContentReferenceID.self, forKey: .contentReferenceID),
            objectiveID: try container.decodeIfPresent(ObjectiveID.self, forKey: .objectiveID)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(contentReferenceID, forKey: .contentReferenceID)
        try container.encodeIfPresent(objectiveID, forKey: .objectiveID)
    }
}

public enum QueryKind: Codable, Hashable, Sendable {
    case projection(ProjectionKind)
    case conversationPage(ConversationPageRequest)
    case contentAvailability(ContentReferenceRequest)

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case value
    }

    private enum Kind: String, Codable, Sendable {
        case projection
        case conversationPage
        case contentAvailability
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "QueryKind")
        switch try container.decode(Kind.self, forKey: .kind) {
        case .projection: self = .projection(try container.decode(ProjectionKind.self, forKey: .value))
        case .conversationPage: self = .conversationPage(try container.decode(ConversationPageRequest.self, forKey: .value))
        case .contentAvailability:
            self = .contentAvailability(try container.decode(ContentReferenceRequest.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .projection(value):
            try container.encode(Kind.projection, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .conversationPage(value):
            try container.encode(Kind.conversationPage, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .contentAvailability(value):
            try container.encode(Kind.contentAvailability, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}

public struct QueryRequest: Codable, Hashable, Sendable {
    public let query: QueryKind

    public init(query: QueryKind) {
        self.query = query
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case query
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "QueryRequest")
        self.init(query: try container.decode(QueryKind.self, forKey: .query))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
    }
}

/// A non-empty text body for one conversation message.
///
/// The original string is retained; trimming is used only to reject bodies that contain no visible
/// text. A body may not contain attachments, files, images, or artifact content. It is bounded by
/// UTF-8 byte length and Unicode scalar count so neither dense multibyte text nor long single-byte
/// text can bypass a limit.
public struct ConversationMessageBody: Codable, Hashable, Sendable {
    public static let maximumUTF8Bytes = ContractLimits.maximumConversationMessageBodyUTF8Bytes
    public static let maximumUnicodeScalars = ContractLimits.maximumConversationMessageBodyUnicodeScalars

    public let rawValue: String

    public init?(_ rawValue: String) {
        guard Self.failureReason(for: rawValue) == nil else { return nil }
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        if let reason = Self.failureReason(for: value) {
            throw ContractDecodingError.invalidConversationMessageBody(reason: reason)
        }
        self.rawValue = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private static func failureReason(for value: String) -> String? {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "body is empty after trimming"
        }
        let bytes = value.utf8.count
        guard bytes <= maximumUTF8Bytes else {
            return "UTF-8 byte length \(bytes) exceeds \(maximumUTF8Bytes)"
        }
        let scalars = value.unicodeScalars.count
        guard scalars <= maximumUnicodeScalars else {
            return "Unicode scalar count \(scalars) exceeds \(maximumUnicodeScalars)"
        }
        return nil
    }
}

/// Client intent to append one bounded text message to a designated conversation.
///
/// This is intent only. It carries no sender-supplied Host identity or position and no approval,
/// tool, objective, task, execution, attachment, or artifact fields. The Host remains responsible for
/// authentication, authorization, persistence, inference, outcomes, and publication.
public struct ConversationMessageSubmission: Codable, Hashable, Sendable {
    public let conversationID: ConversationID
    public let body: ConversationMessageBody

    public init(conversationID: ConversationID, body: ConversationMessageBody) {
        self.conversationID = conversationID
        self.body = body
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case conversationID
        case body
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(
            CodingKeys.self,
            from: decoder,
            type: "ConversationMessageSubmission"
        )
        self.init(
            conversationID: try container.decode(ConversationID.self, forKey: .conversationID),
            body: try container.decode(ConversationMessageBody.self, forKey: .body)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(conversationID, forKey: .conversationID)
        try container.encode(body, forKey: .body)
    }
}

/// Typed payloads for commands that cannot be expressed safely as generic JSON intent.
public enum CommandPayload: Codable, Hashable, Sendable {
    case conversationMessageSubmission(ConversationMessageSubmission)

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case value
    }

    private enum Kind: String, Codable, Sendable {
        case conversationMessageSubmission
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "CommandPayload")
        switch try container.decode(Kind.self, forKey: .kind) {
        case .conversationMessageSubmission:
            self = .conversationMessageSubmission(
                try container.decode(ConversationMessageSubmission.self, forKey: .value)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .conversationMessageSubmission(value):
            try container.encode(Kind.conversationMessageSubmission, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}

/// Client command intents in the shared communication contract. A command is never authority:
/// the Host validates identity, authority, target, parameters, consequences, and required approval.
/// `submitConversationMessage` uses `CommandPayload.conversationMessageSubmission` rather than generic
/// parameters for its message body.
public enum CommandKind: String, Codable, CaseIterable, Sendable {
    case createObjective
    case modifyObjective
    case pauseObjective
    case resumeObjective
    case cancelObjective
    case redirectObjective
    case answerClarification
    case submitApprovalDecision
    case narrowGrant
    case revokeGrant
    case changeSetting
    case configureChannel
    case revokeDevice
    case submitConversationMessage
}

public enum ContractTarget: Codable, Hashable, Sendable {
    case objective(ObjectiveID)
    case conversation(ConversationID)
    case device(DeviceID)
    case approval(ApprovalRequestID)
    case content(ContentReferenceID)
    case none

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case value
    }

    private enum Kind: String, Codable, Sendable {
        case objective
        case conversation
        case device
        case approval
        case content
        case none
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ContractTarget")
        switch try container.decode(Kind.self, forKey: .kind) {
        case .objective: self = .objective(try container.decode(ObjectiveID.self, forKey: .value))
        case .conversation: self = .conversation(try container.decode(ConversationID.self, forKey: .value))
        case .device: self = .device(try container.decode(DeviceID.self, forKey: .value))
        case .approval: self = .approval(try container.decode(ApprovalRequestID.self, forKey: .value))
        case .content: self = .content(try container.decode(ContentReferenceID.self, forKey: .value))
        case .none:
            try rejectFieldsOutsideCase(
                CodingKeys.self,
                from: decoder,
                type: "ContractTarget.none",
                allowed: [CodingKeys.kind.stringValue]
            )
            self = .none
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .objective(value):
            try container.encode(Kind.objective, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .conversation(value):
            try container.encode(Kind.conversation, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .device(value):
            try container.encode(Kind.device, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .approval(value):
            try container.encode(Kind.approval, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .content(value):
            try container.encode(Kind.content, forKey: .kind)
            try container.encode(value, forKey: .value)
        case .none:
            try container.encode(Kind.none, forKey: .kind)
        }
    }
}

public struct CommandRequest: Codable, Hashable, Sendable {
    public let command: CommandKind
    public let target: ContractTarget?
    public let parameters: [String: JSONValue]
    /// A typed command-specific payload. It is optional so existing generic command shapes remain
    /// compatible; `submitConversationMessage` requires its typed payload and forbids generic
    /// parameters.
    public let payload: CommandPayload?

    public init(
        command: CommandKind,
        target: ContractTarget? = nil,
        parameters: [String: JSONValue] = [:],
        payload: CommandPayload? = nil
    ) {
        self.command = command
        self.target = target
        self.parameters = parameters
        self.payload = payload
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case command
        case target
        case parameters
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "CommandRequest")
        self.init(
            command: try container.decode(CommandKind.self, forKey: .command),
            target: try container.decodeIfPresent(ContractTarget.self, forKey: .target),
            parameters: try container.decode([String: JSONValue].self, forKey: .parameters),
            payload: try container.decodeIfPresent(CommandPayload.self, forKey: .payload)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(command, forKey: .command)
        try container.encodeIfPresent(target, forKey: .target)
        try container.encode(parameters, forKey: .parameters)
        try container.encodeIfPresent(payload, forKey: .payload)
    }
}

public enum SynchronizationOperation: Codable, Hashable, Sendable {
    case open(projection: ProjectionKind, cursor: HostPosition?)
    case applied(projection: ProjectionKind, position: HostPosition)

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case projection
        case cursor
        case position
    }

    private enum Kind: String, Codable, Sendable {
        case open
        case applied
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "SynchronizationOperation")
        switch try container.decode(Kind.self, forKey: .kind) {
        case .open:
            try rejectFieldsOutsideCase(
                CodingKeys.self,
                from: decoder,
                type: "SynchronizationOperation.open",
                allowed: [
                    CodingKeys.kind.stringValue,
                    CodingKeys.projection.stringValue,
                    CodingKeys.cursor.stringValue
                ]
            )
            self = .open(
                projection: try container.decode(ProjectionKind.self, forKey: .projection),
                cursor: try container.decodeIfPresent(HostPosition.self, forKey: .cursor)
            )
        case .applied:
            try rejectFieldsOutsideCase(
                CodingKeys.self,
                from: decoder,
                type: "SynchronizationOperation.applied",
                allowed: [
                    CodingKeys.kind.stringValue,
                    CodingKeys.projection.stringValue,
                    CodingKeys.position.stringValue
                ]
            )
            self = .applied(
                projection: try container.decode(ProjectionKind.self, forKey: .projection),
                position: try container.decode(HostPosition.self, forKey: .position)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .open(projection, cursor):
            try container.encode(Kind.open, forKey: .kind)
            try container.encode(projection, forKey: .projection)
            try container.encodeIfPresent(cursor, forKey: .cursor)
        case let .applied(projection, position):
            try container.encode(Kind.applied, forKey: .kind)
            try container.encode(projection, forKey: .projection)
            try container.encode(position, forKey: .position)
        }
    }
}

public struct SynchronizationRequest: Codable, Hashable, Sendable {
    public let operation: SynchronizationOperation

    public init(operation: SynchronizationOperation) {
        self.operation = operation
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case operation
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "SynchronizationRequest")
        self.init(operation: try container.decode(SynchronizationOperation.self, forKey: .operation))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(operation, forKey: .operation)
    }
}
