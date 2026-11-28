import EverydayContract
import Foundation
import Testing

@Suite("Contract schema and semantic validation")
struct ValidationTests {
    private func modifiedFixture(_ name: String, _ changes: [(String, String)]) throws -> Data {
        let string = String(data: try fixtureData(name), encoding: .utf8)!
        var modified = string
        for (needle, replacement) in changes {
            #expect(modified.contains(needle), "Fixture edit target was not found: \(needle)")
            modified = modified.replacingOccurrences(of: needle, with: replacement)
        }
        return Data(modified.utf8)
    }

    private func errorMessage(code: String, message: String = "Validation failed.") -> ContractMessage {
        let envelope = MessageEnvelope(
            messageID: MessageID(rawValue: "msg-error-validation")!,
            correlationID: CorrelationID(rawValue: "corr-error-validation")!,
            sessionID: SessionID(rawValue: "session-error-validation")!,
            payloadKind: .error,
            origin: .host
        )
        let error = ErrorPayload(
            classification: .validation,
            code: code,
            message: message,
            retry: .none
        )
        return ContractMessage(envelope: envelope, payload: .error(error))
    }

    @Test("Unknown envelope fields are rejected")
    func unknownEnvelopeField() throws {
        let data = try modifiedFixture("request-command", [
            ("\"origin\": \"client\"", "\"origin\": \"client\",\n      \"futureAuthority\": true")
        ])
        #expect(throws: ContractDecodingError.self) {
            _ = try JSONContractCoder.decode(data)
        }
    }

    @Test("Unknown nested command fields are rejected")
    func unknownCommandField() throws {
        let data = try modifiedFixture("request-command", [
            ("\"command\": \"createObjective\"", "\"command\": \"createObjective\",\n        \"authority\": \"owner\"")
        ])
        #expect(throws: ContractDecodingError.self) {
            _ = try JSONContractCoder.decode(data)
        }
    }

    @Test("Conversation bodies are not accepted in projection events")
    func conversationBodyIsRejected() throws {
        let data = try modifiedFixture("event-projection", [
            ("\"contentReferenceID\": \"content-007\"", "\"contentReferenceID\": \"content-007\",\n        \"body\": \"secret\"")
        ])
        #expect(throws: ContractDecodingError.self) {
            _ = try JSONContractCoder.decode(data)
        }
    }

    @Test("Commands require an idempotency key")
    func commandRequiresIdempotency() throws {
        let data = try modifiedFixture("request-command", [
            ("    \"idempotencyKey\": \"idem-001\",\n", "")
        ])
        #expect(throws: ContractValidationError.missingIdempotencyKey) {
            _ = try JSONContractCoder.decode(data)
        }
    }

    @Test("Host-authored events require Host position")
    func eventRequiresHostPosition() throws {
        let data = try modifiedFixture("event-projection", [
            ("    \"hostPosition\": 43,\n", "")
        ])
        #expect(throws: ContractValidationError.missingHostPosition) {
            _ = try JSONContractCoder.decode(data)
        }
    }

    @Test("Envelope payload kind must match the payload")
    func payloadKindMustMatch() throws {
        let data = try modifiedFixture("request-command", [
            ("\"payloadKind\": \"request\"", "\"payloadKind\": \"event\"")
        ])
        #expect(throws: ContractValidationError.self) {
            _ = try JSONContractCoder.decode(data)
        }
    }

    @Test("Unsupported protocol and schema versions are refused")
    func unsupportedVersions() throws {
        let wrongProtocol = try modifiedFixture("request-command", [
            ("\"protocolVersion\": \"1.2.0\"", "\"protocolVersion\": \"2.0.0\"")
        ])
        #expect(throws: ContractValidationError.unsupportedProtocolVersion(SemanticVersion.incrementMajor)) {
            _ = try JSONContractCoder.decode(wrongProtocol)
        }

        let wrongSchema = try modifiedFixture("request-command", [
            ("\"schemaVersion\": \"1.2.0\"", "\"schemaVersion\": \"2.0.0\"")
        ])
        #expect(throws: ContractValidationError.unsupportedSchemaVersion(SemanticVersion.incrementMajor)) {
            _ = try JSONContractCoder.decode(wrongSchema)
        }
    }

    @Test("Snapshot envelope position must match the projected position")
    func snapshotPositionMustMatch() throws {
        let message = try fixtureMessage("response-snapshot")
        let envelope = MessageEnvelope(
            messageID: MessageID(rawValue: "msg-mismatch")!,
            correlationID: message.envelope.correlationID,
            sessionID: message.envelope.sessionID,
            hostIdentity: message.envelope.hostIdentity,
            hostPosition: HostPosition(41),
            payloadKind: .response,
            origin: .host
        )
        let invalid = ContractMessage(envelope: envelope, payload: message.payload)
        #expect(throws: ContractValidationError.hostPositionMismatch) {
            try JSONContractCoder.encode(invalid)
        }
    }

    @Test("Conversation page limits are bounded")
    func pageLimitIsBounded() throws {
        let envelope = MessageEnvelope(
            messageID: MessageID(rawValue: "msg-page")!,
            correlationID: CorrelationID(rawValue: "corr-page")!,
            sessionID: SessionID(rawValue: "session-page")!,
            payloadKind: .request,
            origin: .client
        )
        let request = QueryRequest(
            query: .conversationPage(
                ConversationPageRequest(
                    conversationID: ConversationID(rawValue: "conversation-page")!,
                    limit: ContractLimits.maximumPageSize + 1
                )
            )
        )
        let message = ContractMessage(
            envelope: envelope,
            payload: .request(.query(request))
        )
        #expect(throws: ContractValidationError.pageLimitExceeded(
            limit: ContractLimits.maximumPageSize + 1,
            maximum: ContractLimits.maximumPageSize
        )) {
            try ContractValidator.validate(message)
        }
    }

    @Test("Invalid origins are rejected")
    func invalidOriginsAreRejected() throws {
        let invalidRequest = try modifiedFixture("request-command", [
            ("\"origin\": \"client\"", "\"origin\": \"host\"")
        ])
        #expect(throws: ContractValidationError.invalidOrigin(.host, for: .request)) {
            _ = try JSONContractCoder.decode(invalidRequest)
        }

        let invalidResponse = try modifiedFixture("response-snapshot", [
            ("\"origin\": \"host\"", "\"origin\": \"client\"")
        ])
        #expect(throws: ContractValidationError.invalidOrigin(.client, for: .response)) {
            _ = try JSONContractCoder.decode(invalidResponse)
        }

        let invalidEvent = try modifiedFixture("event-projection", [
            ("\"origin\": \"host\"", "\"origin\": \"client\"")
        ])
        #expect(throws: ContractValidationError.invalidOrigin(.client, for: .event)) {
            _ = try JSONContractCoder.decode(invalidEvent)
        }
    }

    @Test("Session or device binding is required except for heartbeats")
    func sessionOrDeviceBindingIsRequiredExceptForHeartbeats() throws {
        let unbound = try modifiedFixture("request-command", [
            ("    \"sessionID\": \"session-001\",\n", "")
        ])
        #expect(throws: ContractValidationError.missingSessionOrDeviceBinding) {
            _ = try JSONContractCoder.decode(unbound)
        }

        let deviceOnly = try modifiedFixture("request-command", [
            ("    \"sessionID\": \"session-001\",\n", "    \"deviceID\": \"device-001\",\n")
        ])
        let decodedDeviceOnly = try JSONContractCoder.decode(deviceOnly)
        #expect(decodedDeviceOnly.envelope.sessionID == nil)
        #expect(decodedDeviceOnly.envelope.deviceID?.rawValue == "device-001")

        let heartbeat = try fixtureMessage("heartbeat")
        #expect(heartbeat.envelope.sessionID == nil)
        #expect(heartbeat.envelope.deviceID == nil)
    }

    @Test("Error representation rejects empty code and message")
    func errorRepresentationRejectsEmptyCodeAndMessage() throws {
        #expect(throws: ContractValidationError.emptyErrorCode) {
            _ = try JSONContractCoder.encode(errorMessage(code: ""))
        }
        #expect(throws: ContractValidationError.emptyErrorMessage) {
            _ = try JSONContractCoder.encode(errorMessage(code: "validation", message: ""))
        }
    }

    @Test("Non-finite Double values are rejected at the validated boundary")
    func nonFiniteDoubleIsRejectedAtValidatedBoundary() throws {
        func message(with value: Double) -> ContractMessage {
            let envelope = MessageEnvelope(
                messageID: MessageID(rawValue: "msg-non-finite")!,
                correlationID: CorrelationID(rawValue: "corr-non-finite")!,
                sessionID: SessionID(rawValue: "session-non-finite")!,
                payloadKind: .request,
                idempotencyKey: IdempotencyKey(rawValue: "idem-non-finite")!,
                origin: .client
            )
            let command = CommandRequest(
                command: .pauseObjective,
                target: .objective(ObjectiveID(rawValue: "objective-non-finite")!),
                parameters: ["value": .double(value)]
            )
            return ContractMessage(envelope: envelope, payload: .request(.command(command)))
        }

        #expect(throws: ContractDecodingError.invalidJSONValue("non-finite number")) {
            _ = try JSONContractCoder.encode(message(with: .infinity))
        }
        #expect(throws: ContractDecodingError.invalidJSONValue("non-finite number")) {
            _ = try JSONContractCoder.encode(message(with: .nan))
        }
    }

    @Test("Invalid ISO-8601 dates are rejected at the validated boundary")
    func invalidISO8601DateIsRejectedAtValidatedBoundary() throws {
        let invalidDate = try modifiedFixture("event-projection", [
            ("\"receivedAt\": \"2026-11-22T12:00:00Z\"", "\"receivedAt\": \"2026-13-22T12:00:00Z\"")
        ])
        #expect(throws: DecodingError.self) {
            _ = try JSONContractCoder.decode(invalidDate)
        }
    }

    @Test("Error code length boundary is inclusive at maximum")
    func errorCodeLengthBoundaryIsInclusiveAtMaximum() throws {
        let atMaximum = String(repeating: "x", count: ContractLimits.maximumErrorCodeLength)
        #expect(try JSONContractCoder.encode(errorMessage(code: atMaximum)).isEmpty == false)

        let overMaximum = String(repeating: "x", count: ContractLimits.maximumErrorCodeLength + 1)
        #expect(throws: ContractValidationError.errorCodeTooLong) {
            _ = try JSONContractCoder.encode(errorMessage(code: overMaximum))
        }
    }

    @Test("Identifier length boundary is inclusive at maximum")
    func identifierLengthBoundaryIsInclusiveAtMaximum() throws {
        let atMaximum = String(repeating: "x", count: ContractLimits.maximumIdentifierLength)
        let overMaximum = String(repeating: "x", count: ContractLimits.maximumIdentifierLength + 1)

        #expect(MessageID(rawValue: atMaximum) != nil)
        #expect(MessageID(rawValue: overMaximum) == nil)

        let accepted = try modifiedFixture("request-command", [
            ("\"messageID\": \"msg-001\"", "\"messageID\": \"\(atMaximum)\"")
        ])
        #expect(try JSONContractCoder.decode(accepted).envelope.messageID.rawValue == atMaximum)

        let rejected = try modifiedFixture("request-command", [
            ("\"messageID\": \"msg-001\"", "\"messageID\": \"\(overMaximum)\"")
        ])
        #expect(throws: ContractDecodingError.invalidIdentifier(type: "message identifier")) {
            _ = try JSONContractCoder.decode(rejected)
        }
    }

    // MARK: - Conversation message submission and publication

    private func submissionBody(_ value: String = "Hello") -> ConversationMessageBody {
        guard let body = ConversationMessageBody(value) else {
            Issue.record("Test body was rejected: \(value)")
            return ConversationMessageBody("fallback")!
        }
        return body
    }

    private func submissionPayload(
        conversationID: String = "conversation-001",
        body: String = "Hello"
    ) -> CommandPayload {
        .conversationMessageSubmission(
            ConversationMessageSubmission(
                conversationID: ConversationID(rawValue: conversationID)!,
                body: submissionBody(body)
            )
        )
    }

    private func submissionEnvelope(
        idempotencyKey: IdempotencyKey? = IdempotencyKey(rawValue: "idem-conversation")!,
        includeHostState: Bool = false
    ) -> MessageEnvelope {
        MessageEnvelope(
            messageID: MessageID(rawValue: "msg-conversation")!,
            correlationID: CorrelationID(rawValue: "corr-conversation")!,
            sessionID: SessionID(rawValue: "session-conversation")!,
            hostIdentity: includeHostState ? HostIdentity(rawValue: "host-primary")! : nil,
            hostPosition: includeHostState ? HostPosition(99) : nil,
            payloadKind: .request,
            idempotencyKey: idempotencyKey,
            origin: .client
        )
    }

    private func submissionMessage(
        target: ContractTarget? = .conversation(
            ConversationID(rawValue: "conversation-001")!
        ),
        parameters: [String: JSONValue] = [:],
        payload: CommandPayload? = nil,
        idempotencyKey: IdempotencyKey? = IdempotencyKey(rawValue: "idem-conversation")!,
        includeHostState: Bool = false
    ) -> ContractMessage {
        ContractMessage(
            envelope: submissionEnvelope(
                idempotencyKey: idempotencyKey,
                includeHostState: includeHostState
            ),
            payload: .request(
                .command(
                    CommandRequest(
                        command: .submitConversationMessage,
                        target: target,
                        parameters: parameters,
                        payload: payload
                    )
                )
            )
        )
    }

    private func hostContentMessage(
        body: String = "Assistant reply",
        envelopePosition: HostPosition = HostPosition(88),
        contentPosition: HostPosition = HostPosition(88)
    ) -> ContractMessage {
        ContractMessage(
            envelope: MessageEnvelope(
                messageID: MessageID(rawValue: "msg-publication")!,
                correlationID: CorrelationID(rawValue: "corr-publication")!,
                causationID: CausationID(rawValue: "cause-submission")!,
                sessionID: SessionID(rawValue: "session-conversation")!,
                hostIdentity: HostIdentity(rawValue: "host-primary")!,
                hostPosition: envelopePosition,
                payloadKind: .event,
                origin: .host
            ),
            payload: .event(
                .conversationMessageContent(
                    ConversationMessageContent(
                        messageID: ConversationMessageID(rawValue: "conversation-message-042")!,
                        conversationID: ConversationID(rawValue: "conversation-001")!,
                        role: .assistant,
                        body: submissionBody(body),
                        hostPosition: contentPosition
                    )
                )
            )
        )
    }

    private func modifiedData(_ data: Data, _ changes: [(String, String)]) throws -> Data {
        let string = String(data: data, encoding: .utf8)!
        var modified = string
        for (needle, replacement) in changes {
            #expect(modified.contains(needle), "JSON edit target was not found: \(needle)")
            modified = modified.replacingOccurrences(of: needle, with: replacement)
        }
        return Data(modified.utf8)
    }

    private func decodedBody(_ json: String) throws -> ConversationMessageBody {
        try JSONDecoder().decode(ConversationMessageBody.self, from: Data(json.utf8))
    }

    @Test("Typed conversation submission round-trips")
    func typedConversationSubmissionRoundTrip() throws {
        let message = submissionMessage(
            payload: submissionPayload(body: "Hello, Developer!")
        )
        let data = try JSONContractCoder.encode(message)
        let decoded = try JSONContractCoder.decode(data)
        #expect(decoded == message)

        guard case let .request(.command(command)) = decoded.payload,
              case let .conversationMessageSubmission(submission)? = command.payload else {
            Issue.record("Expected a typed conversation submission")
            return
        }
        #expect(command.command == .submitConversationMessage)
        #expect(command.parameters.isEmpty)
        #expect(submission.conversationID.rawValue == "conversation-001")
        #expect(submission.body.rawValue == "Hello, Developer!")
        #expect(decoded.envelope.idempotencyKey?.rawValue == "idem-conversation")
        #expect(decoded.envelope.origin == .client)
    }

    @Test("Host-authored conversation content round-trips")
    func hostConversationContentRoundTrip() throws {
        let message = hostContentMessage()
        let data = try JSONContractCoder.encode(message)
        let decoded = try JSONContractCoder.decode(data)
        #expect(decoded == message)

        guard case let .event(.conversationMessageContent(content)) = decoded.payload else {
            Issue.record("Expected Host-authored conversation content")
            return
        }
        #expect(content.role == .assistant)
        #expect(content.body.rawValue == "Assistant reply")
        #expect(content.hostPosition == HostPosition(88))
        #expect(decoded.envelope.hostPosition == content.hostPosition)
        #expect(decoded.envelope.hostIdentity?.rawValue == "host-primary")
        #expect(decoded.envelope.causationID?.rawValue == "cause-submission")
    }

    @Test("Conversation message bodies reject blank text")
    func conversationBodyRejectsBlankText() throws {
        #expect(ConversationMessageBody("") == nil)
        #expect(ConversationMessageBody(" \n\t ") == nil)
        #expect(throws: ContractDecodingError.self) {
            _ = try decodedBody("\"   \"")
        }
        #expect(try decodedBody("\"Hello\"").rawValue == "Hello")
    }

    @Test("Conversation message bodies enforce the inclusive UTF-8 ceiling")
    func conversationBodyUTF8Ceiling() throws {
        // Four-byte scalars make the byte ceiling the first limit reached.
        let scalarsAtByteMaximum = ConversationMessageBody.maximumUTF8Bytes / 4
        let atMaximum = String(repeating: "\u{10000}", count: scalarsAtByteMaximum)
        let overMaximum = String(repeating: "\u{10000}", count: scalarsAtByteMaximum + 1)
        #expect(atMaximum.utf8.count == ConversationMessageBody.maximumUTF8Bytes)
        #expect(overMaximum.unicodeScalars.count < ConversationMessageBody.maximumUnicodeScalars)
        #expect(ConversationMessageBody(atMaximum) != nil)
        #expect(ConversationMessageBody(overMaximum) == nil)
        #expect(throws: ContractDecodingError.self) {
            _ = try decodedBody("\"\(overMaximum)\"")
        }
    }

    @Test("Conversation message bodies enforce the inclusive Unicode scalar ceiling")
    func conversationBodyUnicodeScalarCeiling() throws {
        let atMaximum = String(
            repeating: "a",
            count: ConversationMessageBody.maximumUnicodeScalars
        )
        let overMaximum = String(
            repeating: "a",
            count: ConversationMessageBody.maximumUnicodeScalars + 1
        )
        #expect(overMaximum.utf8.count <= ConversationMessageBody.maximumUTF8Bytes)
        #expect(ConversationMessageBody(atMaximum) != nil)
        #expect(ConversationMessageBody(overMaximum) == nil)
        #expect(throws: ContractDecodingError.self) {
            _ = try decodedBody("\"\(overMaximum)\"")
        }
    }

    @Test("Conversation submission requires an idempotency key")
    func conversationSubmissionRequiresIdempotency() throws {
        #expect(throws: ContractValidationError.missingIdempotencyKey) {
            _ = try JSONContractCoder.encode(
                submissionMessage(
                    payload: submissionPayload(),
                    idempotencyKey: nil
                )
            )
        }
    }

    @Test("Conversation submission rejects wrong typed payloads")
    func conversationSubmissionRejectsWrongPayloadType() throws {
        #expect(throws: ContractValidationError.unexpectedCommandPayload(.pauseObjective)) {
            let command = CommandRequest(
                command: .pauseObjective,
                target: .objective(ObjectiveID(rawValue: "objective-001")!),
                parameters: [:],
                payload: submissionPayload()
            )
            let message = ContractMessage(
                envelope: submissionEnvelope(),
                payload: .request(.command(command))
            )
            _ = try JSONContractCoder.encode(message)
        }

        let validData = try JSONContractCoder.encode(
            submissionMessage(payload: submissionPayload())
        )
        let invalidData = try modifiedData(validData, [
            ("\"kind\":\"conversationMessageSubmission\"", "\"kind\":\"futurePayload\"")
        ])
        #expect(throws: DecodingError.self) {
            _ = try JSONContractCoder.decode(invalidData)
        }
    }

    @Test("Conversation submission rejects unknown fields")
    func conversationSubmissionRejectsUnknownFields() throws {
        let validData = try JSONContractCoder.encode(
            submissionMessage(payload: submissionPayload())
        )
        let invalidData = try modifiedData(validData, [
            ("\"body\":\"Hello\"", "\"body\":\"Hello\",\"senderID\":\"spoofed\"")
        ])
        #expect(throws: ContractDecodingError.self) {
            _ = try JSONContractCoder.decode(invalidData)
        }
    }

    @Test("Conversation submission requires a valid and matching conversation target")
    func conversationSubmissionRequiresValidTarget() throws {
        #expect(throws: ContractValidationError.missingConversationTarget(.submitConversationMessage)) {
            _ = try JSONContractCoder.encode(
                submissionMessage(target: nil, payload: submissionPayload())
            )
        }
        #expect(throws: ContractValidationError.invalidConversationTarget(.submitConversationMessage)) {
            _ = try JSONContractCoder.encode(
                submissionMessage(target: ContractTarget.none, payload: submissionPayload())
            )
        }
        #expect(throws: ContractValidationError.conversationTargetMismatch) {
            _ = try JSONContractCoder.encode(
                submissionMessage(
                    target: .conversation(ConversationID(rawValue: "conversation-002")!),
                    payload: submissionPayload()
                )
            )
        }
    }

    @Test("Conversation submission rejects generic parameter body smuggling")
    func conversationSubmissionRejectsParameterSmuggling() throws {
        #expect(throws: ContractValidationError.commandParametersNotAllowed(.submitConversationMessage)) {
            _ = try JSONContractCoder.encode(
                submissionMessage(
                    parameters: [
                        "body": .string("smuggled"),
                        "nested": .object(["body": .string("smuggled")])
                    ],
                    payload: submissionPayload()
                )
            )
        }
    }

    @Test("Conversation submission does not accept Client-supplied Host state")
    func conversationSubmissionRejectsClientSuppliedHostState() throws {
        #expect(throws: ContractValidationError.clientCommandCarriesHostState) {
            _ = try JSONContractCoder.encode(
                submissionMessage(payload: submissionPayload(), includeHostState: true)
            )
        }

        let validData = try JSONContractCoder.encode(
            submissionMessage(payload: submissionPayload())
        )
        let invalidData = try modifiedData(validData, [
            (
                "\"conversationID\":\"conversation-001\"",
                "\"conversationID\":\"conversation-001\",\"hostPosition\":1"
            )
        ])
        #expect(throws: ContractDecodingError.self) {
            _ = try JSONContractCoder.decode(invalidData)
        }
    }

    @Test("Host-authored conversation content uses strict decoding and matching position")
    func hostConversationContentStrictness() throws {
        let validData = try JSONContractCoder.encode(hostContentMessage())
        let invalidData = try modifiedData(validData, [
            ("\"role\":\"assistant\"", "\"role\":\"assistant\",\"attachment\":\"bad\"")
        ])
        #expect(throws: ContractDecodingError.self) {
            _ = try JSONContractCoder.decode(invalidData)
        }

        let mismatched = hostContentMessage(
            envelopePosition: HostPosition(89),
            contentPosition: HostPosition(88)
        )
        #expect(throws: ContractValidationError.conversationContentPositionMismatch) {
            _ = try JSONContractCoder.encode(mismatched)
        }
    }
}

private extension SemanticVersion {
    static let incrementMajor = SemanticVersion(major: 2, minor: 0, patch: 0)
}
