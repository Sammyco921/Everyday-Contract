import Foundation

/// Acknowledgement meanings are distinct. A delivery receipt never means Host acceptance, and Host
/// acceptance never means completion or approval.
public enum AcknowledgementMeaning: String, Codable, CaseIterable, Sendable {
    case transportReceipt
    case hostAcceptance
    case completionOutcome
}

public struct AcknowledgementPayload: Codable, Hashable, Sendable {
    public let meaning: AcknowledgementMeaning
    public let acknowledgedMessageID: MessageID
    public let hostPosition: HostPosition?

    public init(
        meaning: AcknowledgementMeaning,
        acknowledgedMessageID: MessageID,
        hostPosition: HostPosition? = nil
    ) {
        self.meaning = meaning
        self.acknowledgedMessageID = acknowledgedMessageID
        self.hostPosition = hostPosition
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case meaning
        case acknowledgedMessageID
        case hostPosition
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "AcknowledgementPayload")
        self.init(
            meaning: try container.decode(AcknowledgementMeaning.self, forKey: .meaning),
            acknowledgedMessageID: try container.decode(MessageID.self, forKey: .acknowledgedMessageID),
            hostPosition: try container.decodeIfPresent(HostPosition.self, forKey: .hostPosition)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(meaning, forKey: .meaning)
        try container.encode(acknowledgedMessageID, forKey: .acknowledgedMessageID)
        try container.encodeIfPresent(hostPosition, forKey: .hostPosition)
    }
}

public enum ConnectionState: String, Codable, CaseIterable, Sendable {
    case disconnected
    case connecting
    case authenticating
    case synchronizing
    case live
    case degraded
    case closing
}

public struct HeartbeatPayload: Codable, Hashable, Sendable {
    public let state: ConnectionState

    public init(state: ConnectionState) {
        self.state = state
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case state
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "HeartbeatPayload")
        self.init(state: try container.decode(ConnectionState.self, forKey: .state))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(state, forKey: .state)
    }
}
