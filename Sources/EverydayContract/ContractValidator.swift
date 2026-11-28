import Foundation

public enum ContractValidationError: Error, Equatable, LocalizedError {
    case payloadKindMismatch(expected: PayloadKind, actual: PayloadKind)
    case unsupportedProtocolVersion(SemanticVersion)
    case unsupportedSchemaVersion(SemanticVersion)
    case missingSessionOrDeviceBinding
    case invalidOrigin(MessageOrigin, for: PayloadKind)
    case missingHostPosition
    case missingHostIdentity
    case missingIdempotencyKey
    case hostPositionMismatch
    case hostIdentityMismatch
    case emptyErrorCode
    case errorCodeTooLong
    case emptyErrorMessage
    case pageLimitExceeded(limit: UInt32, maximum: UInt32)
    case parameterCountExceeded(count: Int, maximum: Int)
    case parameterBytesExceeded(bytes: Int, maximum: Int)
    case jsonNestingExceeded(maximum: Int)
    case projectionPayloadMismatch(projection: ProjectionKind)
    case projectionChangeMismatch(projection: ProjectionKind)
    case messageTooLarge(bytes: Int, maximum: Int)
    case missingConversationTarget(CommandKind)
    case invalidConversationTarget(CommandKind)
    case conversationTargetMismatch
    case missingCommandPayload(CommandKind)
    case unexpectedCommandPayload(CommandKind)
    case commandParametersNotAllowed(CommandKind)
    case clientCommandCarriesHostState
    case conversationContentPositionMismatch

    public var errorDescription: String? {
        switch self {
        case let .payloadKindMismatch(expected, actual):
            return "Envelope payload kind \(expected.rawValue) does not match payload \(actual.rawValue)."
        case let .unsupportedProtocolVersion(version):
            return "Unsupported protocol version \(version)."
        case let .unsupportedSchemaVersion(version):
            return "Unsupported schema version \(version)."
        case .missingSessionOrDeviceBinding:
            return "A session or device identity is required."
        case let .invalidOrigin(origin, kind):
            return "Message origin \(origin.rawValue) is not valid for \(kind.rawValue)."
        case .missingHostPosition:
            return "Host-authored state requires a Host position."
        case .missingHostIdentity:
            return "Host-authored state requires a Host identity."
        case .missingIdempotencyKey:
            return "A command requires an idempotency key."
        case .hostPositionMismatch:
            return "Envelope Host position does not match the projected Host position."
        case .hostIdentityMismatch:
            return "Envelope Host identity does not match the projected Host identity."
        case .emptyErrorCode:
            return "Error code must not be empty."
        case .errorCodeTooLong:
            return "Error code exceeds the contract limit."
        case .emptyErrorMessage:
            return "Error message must not be empty."
        case let .pageLimitExceeded(limit, maximum):
            return "Conversation page limit \(limit) exceeds \(maximum)."
        case let .parameterCountExceeded(count, maximum):
            return "Command parameter count \(count) exceeds \(maximum)."
        case let .parameterBytesExceeded(bytes, maximum):
            return "Command parameter payload \(bytes) bytes exceeds \(maximum)."
        case let .jsonNestingExceeded(maximum):
            return "JSON value nesting exceeds the maximum depth of \(maximum)."
        case let .projectionPayloadMismatch(projection):
            return "Snapshot payload does not match projection \(projection.rawValue)."
        case let .projectionChangeMismatch(projection):
            return "A delta change does not belong to projection \(projection.rawValue)."
        case let .messageTooLarge(bytes, maximum):
            return "Message size \(bytes) bytes exceeds \(maximum)."
        case let .missingConversationTarget(command):
            return "\(command.rawValue) requires a conversation target."
        case let .invalidConversationTarget(command):
            return "\(command.rawValue) requires a conversation target."
        case .conversationTargetMismatch:
            return "The command target and submission conversation do not match."
        case let .missingCommandPayload(command):
            return "\(command.rawValue) requires its typed command payload."
        case let .unexpectedCommandPayload(command):
            return "\(command.rawValue) does not accept that typed command payload."
        case let .commandParametersNotAllowed(command):
            return "\(command.rawValue) does not accept generic command parameters."
        case .clientCommandCarriesHostState:
            return "A Client command may not carry Host identity or Host position."
        case .conversationContentPositionMismatch:
            return "Conversation message content position does not match the envelope."
        }
    }
}

/// Structural and semantic validation shared by both applications. It is deliberately limited to
/// contract rules; no Host execution state or User Application view state is evaluated here.
public enum ContractValidator {
    public static func validate(_ message: ContractMessage) throws {
        let envelope = message.envelope
        let payloadKind = message.payload.payloadKind
        guard envelope.payloadKind == payloadKind else {
            throw ContractValidationError.payloadKindMismatch(
                expected: envelope.payloadKind,
                actual: payloadKind
            )
        }

        let profile = ContractProfiles.current
        guard profile.supportedProtocolRange.supports(envelope.protocolVersion) else {
            throw ContractValidationError.unsupportedProtocolVersion(envelope.protocolVersion)
        }
        guard envelope.schemaVersion == profile.schemaVersion else {
            throw ContractValidationError.unsupportedSchemaVersion(envelope.schemaVersion)
        }

        if payloadKind != .heartbeat, envelope.sessionID == nil, envelope.deviceID == nil {
            throw ContractValidationError.missingSessionOrDeviceBinding
        }

        try validateOrigin(envelope.origin, payloadKind: payloadKind)

        switch message.payload {
        case let .request(request):
            try validateRequest(request, envelope: envelope)
        case let .response(response):
            try validateResponse(response, envelope: envelope)
        case let .event(event):
            try requireHostState(envelope)
            try validateEvent(event, envelope: envelope)
        case let .acknowledgement(acknowledgement):
            if acknowledgement.meaning == .completionOutcome, envelope.origin == .host {
                try requireHostState(envelope)
            }
        case let .error(error):
            try validateError(error)
        case .heartbeat:
            break
        }
    }

    private static func validateOrigin(_ origin: MessageOrigin, payloadKind: PayloadKind) throws {
        switch payloadKind {
        case .request:
            guard origin == .client else {
                throw ContractValidationError.invalidOrigin(origin, for: payloadKind)
            }
        case .response, .event:
            guard origin == .host else {
                throw ContractValidationError.invalidOrigin(origin, for: payloadKind)
            }
        case .acknowledgement, .error, .heartbeat:
            break
        }
    }

    private static func validateRequest(
        _ request: RequestPayload,
        envelope: MessageEnvelope
    ) throws {
        switch request {
        case let .query(query):
            if case let .conversationPage(page) = query.query {
                guard page.limit <= ContractLimits.maximumPageSize else {
                    throw ContractValidationError.pageLimitExceeded(
                        limit: page.limit,
                        maximum: ContractLimits.maximumPageSize
                    )
                }
            }
        case let .command(command):
            guard envelope.idempotencyKey != nil else {
                throw ContractValidationError.missingIdempotencyKey
            }
            if command.command == .submitConversationMessage {
                try validateConversationMessageSubmission(command, envelope: envelope)
            } else {
                guard command.payload == nil else {
                    throw ContractValidationError.unexpectedCommandPayload(command.command)
                }
                try validateJSONMetadata(command.parameters)
            }
        case .synchronize:
            break
        }
    }

    private static func validateConversationMessageSubmission(
        _ command: CommandRequest,
        envelope: MessageEnvelope
    ) throws {
        guard let target = command.target else {
            throw ContractValidationError.missingConversationTarget(command.command)
        }
        guard case let .conversation(targetConversationID) = target else {
            throw ContractValidationError.invalidConversationTarget(command.command)
        }
        guard let payload = command.payload else {
            throw ContractValidationError.missingCommandPayload(command.command)
        }
        guard case let .conversationMessageSubmission(submission) = payload else {
            throw ContractValidationError.unexpectedCommandPayload(command.command)
        }
        guard submission.conversationID == targetConversationID else {
            throw ContractValidationError.conversationTargetMismatch
        }
        guard command.parameters.isEmpty else {
            throw ContractValidationError.commandParametersNotAllowed(command.command)
        }
        guard envelope.hostIdentity == nil, envelope.hostPosition == nil else {
            throw ContractValidationError.clientCommandCarriesHostState
        }
    }

    private static func validateResponse(
        _ response: ResponsePayload,
        envelope: MessageEnvelope
    ) throws {
        switch response {
        case let .queryResult(result):
            switch result {
            case let .projection(snapshot):
                try validateHostAuthoredSnapshot(snapshot, envelope: envelope)
            case let .conversationPage(page):
                try requireHostState(envelope)
                try validatePageSize(page)
                guard envelope.hostPosition == page.hostPosition else {
                    throw ContractValidationError.hostPositionMismatch
                }
            case .contentAvailability:
                // Availability and integrity are committed Host-reported facts about a content item.
                try requireHostState(envelope)
            }
        case let .commandResult(result):
            // Command outcomes may be positionless when no committed position applies. If a position
            // is reported, the envelope must carry Host state and agree with it.
            if let position = result.hostPosition {
                try requireHostState(envelope)
                guard envelope.hostPosition == position else {
                    throw ContractValidationError.hostPositionMismatch
                }
            }
            if let payload = result.result {
                try validateJSONMetadata(payload)
            }
        case let .synchronization(synchronization):
            switch synchronization {
            case let .snapshot(snapshot):
                try validateHostAuthoredSnapshot(snapshot, envelope: envelope)
            case let .delta(delta):
                try requireHostState(envelope)
                guard envelope.hostPosition == delta.toPosition else {
                    throw ContractValidationError.hostPositionMismatch
                }
                guard envelope.hostIdentity == delta.hostIdentity else {
                    throw ContractValidationError.hostIdentityMismatch
                }
                try validateDeltaConsistency(delta)
            case let .applied(position):
                try requireHostState(envelope)
                guard envelope.hostPosition == position else {
                    throw ContractValidationError.hostPositionMismatch
                }
            case let .unavailable(error):
                try validateError(error)
            }
        }
    }

    private static func validateHostAuthoredSnapshot(
        _ snapshot: ProjectionSnapshot,
        envelope: MessageEnvelope
    ) throws {
        try requireHostState(envelope)
        guard envelope.hostPosition == snapshot.hostPosition else {
            throw ContractValidationError.hostPositionMismatch
        }
        guard envelope.hostIdentity == snapshot.hostIdentity else {
            throw ContractValidationError.hostIdentityMismatch
        }
        try validateSnapshotConsistency(snapshot)
    }

    private static func validateSnapshotConsistency(_ snapshot: ProjectionSnapshot) throws {
        guard projectionKind(for: snapshot.payload) == snapshot.projection else {
            throw ContractValidationError.projectionPayloadMismatch(projection: snapshot.projection)
        }
        if case let .conversations(page) = snapshot.payload {
            try validatePageSize(page)
            guard page.hostPosition == snapshot.hostPosition else {
                throw ContractValidationError.hostPositionMismatch
            }
        }
    }

    private static func validateDeltaConsistency(_ delta: ProjectionDelta) throws {
        for change in delta.changes {
            guard projectionKind(for: change) == delta.projection else {
                throw ContractValidationError.projectionChangeMismatch(projection: delta.projection)
            }
            if case let .approvalAvailable(notice) = change {
                guard notice.hostPosition == delta.toPosition else {
                    throw ContractValidationError.hostPositionMismatch
                }
            }
        }
    }

    private static func validateEvent(_ event: EventPayload, envelope: MessageEnvelope) throws {
        switch event {
        case let .approvalAvailable(notice):
            guard envelope.hostPosition == notice.hostPosition else {
                throw ContractValidationError.hostPositionMismatch
            }
        case let .projectionChanged(change):
            if case let .approvalAvailable(notice) = change {
                guard envelope.hostPosition == notice.hostPosition else {
                    throw ContractValidationError.hostPositionMismatch
                }
            }
        case let .conversationMessageContent(content):
            guard envelope.hostPosition == content.hostPosition else {
                throw ContractValidationError.conversationContentPositionMismatch
            }
        case .hostCondition, .channelCondition, .recoveryNotice:
            break
        }
    }

    private static func validatePageSize(_ page: ConversationPage) throws {
        guard page.items.count <= Int(ContractLimits.maximumPageSize) else {
            throw ContractValidationError.pageLimitExceeded(
                limit: UInt32(clamping: page.items.count),
                maximum: ContractLimits.maximumPageSize
            )
        }
    }

    /// Applies the shared JSON metadata limits to command parameters and command-result metadata.
    /// The existing `parameter*` errors are reused on both sides to preserve the public error surface;
    /// they report the same limit violation regardless of which side carried the metadata.
    private static func validateJSONMetadata(_ metadata: [String: JSONValue]) throws {
        guard metadata.count <= ContractLimits.maximumParameterCount else {
            throw ContractValidationError.parameterCountExceeded(
                count: metadata.count,
                maximum: ContractLimits.maximumParameterCount
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let bytes = try encoder.encode(metadata).count
        guard bytes <= ContractLimits.maximumParameterBytes else {
            throw ContractValidationError.parameterBytesExceeded(
                bytes: bytes,
                maximum: ContractLimits.maximumParameterBytes
            )
        }
        try validateJSONNesting(metadata.values)
    }

    private static func validateJSONNesting(_ values: Dictionary<String, JSONValue>.Values) throws {
        for value in values {
            guard value.nestingDepth <= ContractLimits.maximumJSONNestingDepth else {
                throw ContractValidationError.jsonNestingExceeded(
                    maximum: ContractLimits.maximumJSONNestingDepth
                )
            }
        }
    }

    private static func projectionKind(for payload: ProjectionPayload) -> ProjectionKind {
        switch payload {
        case .tasks: return .tasks
        case .conversations: return .conversations
        case .approvals: return .approvals
        case .hostStatus: return .hostStatus
        case .channelStatus: return .channelStatus
        }
    }

    private static func projectionKind(for change: ProjectionChange) -> ProjectionKind {
        switch change {
        case .taskUpserted, .taskRemoved: return .tasks
        case .conversationMessageAppended, .conversationUpdated: return .conversations
        case .approvalAvailable: return .approvals
        case .hostConditionChanged: return .hostStatus
        case .channelConditionChanged: return .channelStatus
        }
    }

    private static func requireHostState(_ envelope: MessageEnvelope) throws {
        guard envelope.hostPosition != nil else {
            throw ContractValidationError.missingHostPosition
        }
        guard envelope.hostIdentity != nil else {
            throw ContractValidationError.missingHostIdentity
        }
    }

    private static func validateError(_ error: ErrorPayload) throws {
        guard !error.code.isEmpty else {
            throw ContractValidationError.emptyErrorCode
        }
        guard error.code.count <= ContractLimits.maximumErrorCodeLength else {
            throw ContractValidationError.errorCodeTooLong
        }
        guard !error.message.isEmpty else {
            throw ContractValidationError.emptyErrorMessage
        }
    }
}
