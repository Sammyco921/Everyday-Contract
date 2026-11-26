import Foundation

public enum MessageOrigin: String, Codable, Sendable {
    case client
    case host
}

public enum PayloadKind: String, Codable, CaseIterable, Sendable {
    case request
    case response
    case event
    case acknowledgement
    case error
    case heartbeat
}

/// Required semantics for every protocol message. Host identity and position are present on
/// Host-authored state messages; they are never inferred from arrival order.
public struct MessageEnvelope: Codable, Hashable, Sendable {
    public let messageID: MessageID
    public let correlationID: CorrelationID
    public let causationID: CausationID?
    public let sessionID: SessionID?
    public let deviceID: DeviceID?
    public let hostIdentity: HostIdentity?
    public let hostPosition: HostPosition?
    public let protocolVersion: SemanticVersion
    public let schemaVersion: SemanticVersion
    public let payloadKind: PayloadKind
    public let idempotencyKey: IdempotencyKey?
    public let origin: MessageOrigin

    public init(
        messageID: MessageID,
        correlationID: CorrelationID,
        causationID: CausationID? = nil,
        sessionID: SessionID? = nil,
        deviceID: DeviceID? = nil,
        hostIdentity: HostIdentity? = nil,
        hostPosition: HostPosition? = nil,
        protocolVersion: SemanticVersion = ContractProfiles.current.protocolVersion,
        schemaVersion: SemanticVersion = ContractProfiles.current.schemaVersion,
        payloadKind: PayloadKind,
        idempotencyKey: IdempotencyKey? = nil,
        origin: MessageOrigin
    ) {
        self.messageID = messageID
        self.correlationID = correlationID
        self.causationID = causationID
        self.sessionID = sessionID
        self.deviceID = deviceID
        self.hostIdentity = hostIdentity
        self.hostPosition = hostPosition
        self.protocolVersion = protocolVersion
        self.schemaVersion = schemaVersion
        self.payloadKind = payloadKind
        self.idempotencyKey = idempotencyKey
        self.origin = origin
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case messageID
        case correlationID
        case causationID
        case sessionID
        case deviceID
        case hostIdentity
        case hostPosition
        case protocolVersion
        case schemaVersion
        case payloadKind
        case idempotencyKey
        case origin
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "MessageEnvelope")
        self.init(
            messageID: try container.decode(MessageID.self, forKey: .messageID),
            correlationID: try container.decode(CorrelationID.self, forKey: .correlationID),
            causationID: try container.decodeIfPresent(CausationID.self, forKey: .causationID),
            sessionID: try container.decodeIfPresent(SessionID.self, forKey: .sessionID),
            deviceID: try container.decodeIfPresent(DeviceID.self, forKey: .deviceID),
            hostIdentity: try container.decodeIfPresent(HostIdentity.self, forKey: .hostIdentity),
            hostPosition: try container.decodeIfPresent(HostPosition.self, forKey: .hostPosition),
            protocolVersion: try container.decode(SemanticVersion.self, forKey: .protocolVersion),
            schemaVersion: try container.decode(SemanticVersion.self, forKey: .schemaVersion),
            payloadKind: try container.decode(PayloadKind.self, forKey: .payloadKind),
            idempotencyKey: try container.decodeIfPresent(IdempotencyKey.self, forKey: .idempotencyKey),
            origin: try container.decode(MessageOrigin.self, forKey: .origin)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(messageID, forKey: .messageID)
        try container.encode(correlationID, forKey: .correlationID)
        try container.encodeIfPresent(causationID, forKey: .causationID)
        try container.encodeIfPresent(sessionID, forKey: .sessionID)
        try container.encodeIfPresent(deviceID, forKey: .deviceID)
        try container.encodeIfPresent(hostIdentity, forKey: .hostIdentity)
        try container.encodeIfPresent(hostPosition, forKey: .hostPosition)
        try container.encode(protocolVersion, forKey: .protocolVersion)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(payloadKind, forKey: .payloadKind)
        try container.encodeIfPresent(idempotencyKey, forKey: .idempotencyKey)
        try container.encode(origin, forKey: .origin)
    }
}

public enum MessagePayload: Codable, Hashable, Sendable {
    case request(RequestPayload)
    case response(ResponsePayload)
    case event(EventPayload)
    case acknowledgement(AcknowledgementPayload)
    case error(ErrorPayload)
    case heartbeat(HeartbeatPayload)

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case kind
        case value
    }

    private enum Kind: String, Codable, Sendable {
        case request
        case response
        case event
        case acknowledgement
        case error
        case heartbeat
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "MessagePayload")
        switch try container.decode(Kind.self, forKey: .kind) {
        case .request:
            self = .request(try container.decode(RequestPayload.self, forKey: .value))
        case .response:
            self = .response(try container.decode(ResponsePayload.self, forKey: .value))
        case .event:
            self = .event(try container.decode(EventPayload.self, forKey: .value))
        case .acknowledgement:
            self = .acknowledgement(try container.decode(AcknowledgementPayload.self, forKey: .value))
        case .error:
            self = .error(try container.decode(ErrorPayload.self, forKey: .value))
        case .heartbeat:
            self = .heartbeat(try container.decode(HeartbeatPayload.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .request(value):
            try container.encode(Kind.request, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .response(value):
            try container.encode(Kind.response, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .event(value):
            try container.encode(Kind.event, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .acknowledgement(value):
            try container.encode(Kind.acknowledgement, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .error(value):
            try container.encode(Kind.error, forKey: .kind)
            try container.encode(value, forKey: .value)
        case let .heartbeat(value):
            try container.encode(Kind.heartbeat, forKey: .kind)
            try container.encode(value, forKey: .value)
        }
    }

    public var payloadKind: PayloadKind {
        switch self {
        case .request: return .request
        case .response: return .response
        case .event: return .event
        case .acknowledgement: return .acknowledgement
        case .error: return .error
        case .heartbeat: return .heartbeat
        }
    }
}

public struct ContractMessage: Codable, Hashable, Sendable {
    public let envelope: MessageEnvelope
    public let payload: MessagePayload

    public init(envelope: MessageEnvelope, payload: MessagePayload) {
        self.envelope = envelope
        self.payload = payload
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case envelope
        case payload
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ContractMessage")
        self.init(
            envelope: try container.decode(MessageEnvelope.self, forKey: .envelope),
            payload: try container.decode(MessagePayload.self, forKey: .payload)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(envelope, forKey: .envelope)
        try container.encode(payload, forKey: .payload)
    }
}
