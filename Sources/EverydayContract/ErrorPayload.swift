import Foundation

public enum ErrorClass: String, Codable, CaseIterable, Sendable {
    case transport
    case authentication
    case authorization
    case staleConsistency
    case validation
    case hostCondition
    case channelCondition
}

public enum RetryGuidance: String, Codable, CaseIterable, Sendable {
    case none
    case afterReconnect
    case afterResynchronization
    case afterOwnerAction
}

public struct ErrorPayload: Codable, Hashable, Sendable {
    public let classification: ErrorClass
    public let code: String
    public let message: String
    public let nextStep: String?
    public let affectedObjectiveID: ObjectiveID?
    public let retry: RetryGuidance

    public init(
        classification: ErrorClass,
        code: String,
        message: String,
        nextStep: String? = nil,
        affectedObjectiveID: ObjectiveID? = nil,
        retry: RetryGuidance
    ) {
        self.classification = classification
        self.code = code
        self.message = message
        self.nextStep = nextStep
        self.affectedObjectiveID = affectedObjectiveID
        self.retry = retry
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case classification
        case code
        case message
        case nextStep
        case affectedObjectiveID
        case retry
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ErrorPayload")
        self.init(
            classification: try container.decode(ErrorClass.self, forKey: .classification),
            code: try container.decode(String.self, forKey: .code),
            message: try container.decode(String.self, forKey: .message),
            nextStep: try container.decodeIfPresent(String.self, forKey: .nextStep),
            affectedObjectiveID: try container.decodeIfPresent(ObjectiveID.self, forKey: .affectedObjectiveID),
            retry: try container.decode(RetryGuidance.self, forKey: .retry)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(classification, forKey: .classification)
        try container.encode(code, forKey: .code)
        try container.encode(message, forKey: .message)
        try container.encodeIfPresent(nextStep, forKey: .nextStep)
        try container.encodeIfPresent(affectedObjectiveID, forKey: .affectedObjectiveID)
        try container.encode(retry, forKey: .retry)
    }
}
