import Foundation

public enum HostConditionKind: String, Codable, CaseIterable, Sendable {
    case healthy
    case degraded
    case recoveryLimited
    case storagePressure
    case inferenceUnavailable
}

public struct HostCondition: Codable, Hashable, Sendable {
    public let condition: HostConditionKind
    public let affectedObjectiveID: ObjectiveID?
    public let detail: String?

    public init(
        condition: HostConditionKind,
        affectedObjectiveID: ObjectiveID? = nil,
        detail: String? = nil
    ) {
        self.condition = condition
        self.affectedObjectiveID = affectedObjectiveID
        self.detail = detail
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case condition
        case affectedObjectiveID
        case detail
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "HostCondition")
        self.init(
            condition: try container.decode(HostConditionKind.self, forKey: .condition),
            affectedObjectiveID: try container.decodeIfPresent(ObjectiveID.self, forKey: .affectedObjectiveID),
            detail: try container.decodeIfPresent(String.self, forKey: .detail)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(condition, forKey: .condition)
        try container.encodeIfPresent(affectedObjectiveID, forKey: .affectedObjectiveID)
        try container.encodeIfPresent(detail, forKey: .detail)
    }
}

public enum ChannelStatus: String, Codable, CaseIterable, Sendable {
    case available
    case degraded
    case unavailable
}

public struct ChannelCondition: Codable, Hashable, Sendable {
    public let channel: CommunicationChannel
    public let status: ChannelStatus
    public let detail: String?

    public init(channel: CommunicationChannel, status: ChannelStatus, detail: String? = nil) {
        self.channel = channel
        self.status = status
        self.detail = detail
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case channel
        case status
        case detail
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ChannelCondition")
        self.init(
            channel: try container.decode(CommunicationChannel.self, forKey: .channel),
            status: try container.decode(ChannelStatus.self, forKey: .status),
            detail: try container.decodeIfPresent(String.self, forKey: .detail)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(channel, forKey: .channel)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(detail, forKey: .detail)
    }
}

public struct ApprovalNotice: Codable, Hashable, Sendable {
    public let approvalRequestID: ApprovalRequestID
    public let objectiveID: ObjectiveID?
    public let hostPosition: HostPosition
    public let isConsequential: Bool

    public init(
        approvalRequestID: ApprovalRequestID,
        objectiveID: ObjectiveID? = nil,
        hostPosition: HostPosition,
        isConsequential: Bool
    ) {
        self.approvalRequestID = approvalRequestID
        self.objectiveID = objectiveID
        self.hostPosition = hostPosition
        self.isConsequential = isConsequential
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case approvalRequestID
        case objectiveID
        case hostPosition
        case isConsequential
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ApprovalNotice")
        self.init(
            approvalRequestID: try container.decode(ApprovalRequestID.self, forKey: .approvalRequestID),
            objectiveID: try container.decodeIfPresent(ObjectiveID.self, forKey: .objectiveID),
            hostPosition: try container.decode(HostPosition.self, forKey: .hostPosition),
            isConsequential: try container.decode(Bool.self, forKey: .isConsequential)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(approvalRequestID, forKey: .approvalRequestID)
        try container.encodeIfPresent(objectiveID, forKey: .objectiveID)
        try container.encode(hostPosition, forKey: .hostPosition)
        try container.encode(isConsequential, forKey: .isConsequential)
    }
}

public enum RecoveryNoticeStatus: String, Codable, CaseIterable, Sendable {
    case started
    case completed
    case parkedUncertainEffects
    case integrityFailure
}

public struct RecoveryNotice: Codable, Hashable, Sendable {
    public let status: RecoveryNoticeStatus
    public let affectedObjectiveID: ObjectiveID?
    public let detail: String?

    public init(
        status: RecoveryNoticeStatus,
        affectedObjectiveID: ObjectiveID? = nil,
        detail: String? = nil
    ) {
        self.status = status
        self.affectedObjectiveID = affectedObjectiveID
        self.detail = detail
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case status
        case affectedObjectiveID
        case detail
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "RecoveryNotice")
        self.init(
            status: try container.decode(RecoveryNoticeStatus.self, forKey: .status),
            affectedObjectiveID: try container.decodeIfPresent(ObjectiveID.self, forKey: .affectedObjectiveID),
            detail: try container.decodeIfPresent(String.self, forKey: .detail)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encodeIfPresent(affectedObjectiveID, forKey: .affectedObjectiveID)
        try container.encodeIfPresent(detail, forKey: .detail)
    }
}

public enum EventPayload: Codable, Hashable, Sendable {
    case projectionChanged(ProjectionChange)
    case hostCondition(HostCondition)
    case channelCondition(ChannelCondition)
    case approvalAvailable(ApprovalNotice)
    case recoveryNotice(RecoveryNotice)

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case value
    }

    private enum Kind: String, Codable, Sendable {
        case projectionChanged
        case hostCondition
        case channelCondition
        case approvalAvailable
        case recoveryNotice
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "EventPayload")
        switch try container.decode(Kind.self, forKey: .kind) {
        case .projectionChanged:
            self = .projectionChanged(try container.decode(ProjectionChange.self, forKey: .value))
        case .hostCondition:
            self = .hostCondition(try container.decode(HostCondition.self, forKey: .value))
        case .channelCondition:
            self = .channelCondition(try container.decode(ChannelCondition.self, forKey: .value))
        case .approvalAvailable:
            self = .approvalAvailable(try container.decode(ApprovalNotice.self, forKey: .value))
        case .recoveryNotice:
            self = .recoveryNotice(try container.decode(RecoveryNotice.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .projectionChanged(value):
            try container.encode(Kind.projectionChanged, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .hostCondition(value):
            try container.encode(Kind.hostCondition, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .channelCondition(value):
            try container.encode(Kind.channelCondition, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .approvalAvailable(value):
            try container.encode(Kind.approvalAvailable, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .recoveryNotice(value):
            try container.encode(Kind.recoveryNotice, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }
}
