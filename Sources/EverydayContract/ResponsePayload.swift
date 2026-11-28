import Foundation

public enum ResponsePayload: Codable, Hashable, Sendable {
    case queryResult(QueryResult)
    case commandResult(CommandResult)
    case synchronization(SynchronizationResponse)

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case value
    }

    private enum Kind: String, Codable, Sendable {
        case queryResult
        case commandResult
        case synchronization
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ResponsePayload")
        switch try container.decode(Kind.self, forKey: .kind) {
        case .queryResult: self = .queryResult(try container.decode(QueryResult.self, forKey: .value))
        case .commandResult: self = .commandResult(try container.decode(CommandResult.self, forKey: .value))
        case .synchronization: self = .synchronization(try container.decode(SynchronizationResponse.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .queryResult(value):
            try container.encode(Kind.queryResult, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .commandResult(value):
            try container.encode(Kind.commandResult, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .synchronization(value):
            try container.encode(Kind.synchronization, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}

/// A Host-authored answer to a query.
///
/// - `projection` and `conversationPage` represent committed Host state and require Host identity and
///   position on the envelope. The page's own position must agree with the envelope.
/// - `contentAvailability` reports committed availability/integrity facts and requires Host identity
///   and position on the envelope. The envelope position is the point at which the fact was reported.
public enum QueryResult: Codable, Hashable, Sendable {
    case projection(ProjectionSnapshot)
    case conversationPage(ConversationPage)
    case contentAvailability(ContentAvailability)

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
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "QueryResult")
        switch try container.decode(Kind.self, forKey: .kind) {
        case .projection: self = .projection(try container.decode(ProjectionSnapshot.self, forKey: .value))
        case .conversationPage: self = .conversationPage(try container.decode(ConversationPage.self, forKey: .value))
        case .contentAvailability:
            self = .contentAvailability(try container.decode(ContentAvailability.self, forKey: .value))
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

public enum CommandStatus: String, Codable, CaseIterable, Sendable {
    case accepted
    case rejected
    case completed
    case failed
    case cancelled
    case needsOwner
}

/// Host-authored result for a successfully created objective.
///
/// The identifier is Host-generated. Contract does not infer persistence or authority from it.
public struct ObjectiveCreationResult: Codable, Hashable, Sendable {
    public let createdObjectiveID: ObjectiveID

    public init(createdObjectiveID: ObjectiveID) {
        self.createdObjectiveID = createdObjectiveID
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case createdObjectiveID
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(
            CodingKeys.self,
            from: decoder,
            type: "ObjectiveCreationResult"
        )
        self.init(
            createdObjectiveID: try container.decode(ObjectiveID.self, forKey: .createdObjectiveID)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(createdObjectiveID, forKey: .createdObjectiveID)
    }
}

/// Typed command-result payloads. Generic metadata and typed results are separate representations
/// and must never be present on the same `CommandResult`.
public enum CommandResultPayload: Codable, Hashable, Sendable {
    case objectiveCreation(ObjectiveCreationResult)

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case value
    }

    private enum Kind: String, Codable, Sendable {
        case objectiveCreation
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(
            CodingKeys.self,
            from: decoder,
            type: "CommandResultPayload"
        )
        switch try container.decode(Kind.self, forKey: .kind) {
        case .objectiveCreation:
            self = .objectiveCreation(
                try container.decode(ObjectiveCreationResult.self, forKey: .value)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .objectiveCreation(value):
            try container.encode(Kind.objectiveCreation, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}

/// A Host-authored command outcome.
///
/// A command result is not a projection replacement and may be positionless when no committed
/// position applies, such as a rejected command. When `hostPosition` is present, the envelope must
/// carry the matching Host identity and position. Existing commands use the generic `result`; typed
/// commands use `typedResult`. The two representations are mutually exclusive.
public struct CommandResult: Codable, Hashable, Sendable {
    public let status: CommandStatus
    public let hostPosition: HostPosition?
    public let acceptedMessageID: MessageID?
    public let result: [String: JSONValue]?
    public let typedResult: CommandResultPayload?

    public init(
        status: CommandStatus,
        hostPosition: HostPosition? = nil,
        acceptedMessageID: MessageID? = nil,
        result: [String: JSONValue]? = nil,
        typedResult: CommandResultPayload? = nil
    ) {
        self.status = status
        self.hostPosition = hostPosition
        self.acceptedMessageID = acceptedMessageID
        self.result = result
        self.typedResult = typedResult
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case status
        case hostPosition
        case acceptedMessageID
        case result
        case typedResult
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "CommandResult")
        let result = try container.decodeIfPresent([String: JSONValue].self, forKey: .result)
        let typedResult = try container.decodeIfPresent(CommandResultPayload.self, forKey: .typedResult)
        guard result == nil || typedResult == nil else {
            throw ContractDecodingError.invalidCommandResult(
                reason: "result and typedResult are mutually exclusive"
            )
        }
        self.init(
            status: try container.decode(CommandStatus.self, forKey: .status),
            hostPosition: try container.decodeIfPresent(HostPosition.self, forKey: .hostPosition),
            acceptedMessageID: try container.decodeIfPresent(MessageID.self, forKey: .acceptedMessageID),
            result: result,
            typedResult: typedResult
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(hostPosition, forKey: .hostPosition)
        try container.encodeIfPresent(acceptedMessageID, forKey: .acceptedMessageID)
        try container.encodeIfPresent(result, forKey: .result)
        try container.encodeIfPresent(typedResult, forKey: .typedResult)
    }
}

/// A Host-authored synchronization result.
///
/// Snapshots, deltas, and applied acknowledgements represent committed Host state and require Host
/// identity and position on the envelope. An `applied` position must equal the envelope position.
/// `unavailable` is an error response and may be positionless.
public enum SynchronizationResponse: Codable, Hashable, Sendable {
    case snapshot(ProjectionSnapshot)
    case delta(ProjectionDelta)
    case applied(HostPosition)
    case unavailable(ErrorPayload)

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case value
    }

    private enum Kind: String, Codable, Sendable {
        case snapshot
        case delta
        case applied
        case unavailable
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "SynchronizationResponse")
        switch try container.decode(Kind.self, forKey: .kind) {
        case .snapshot: self = .snapshot(try container.decode(ProjectionSnapshot.self, forKey: .value))
        case .delta: self = .delta(try container.decode(ProjectionDelta.self, forKey: .value))
        case .applied: self = .applied(try container.decode(HostPosition.self, forKey: .value))
        case .unavailable: self = .unavailable(try container.decode(ErrorPayload.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .snapshot(value):
            try container.encode(Kind.snapshot, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .delta(value):
            try container.encode(Kind.delta, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .applied(value):
            try container.encode(Kind.applied, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .unavailable(value):
            try container.encode(Kind.unavailable, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}
