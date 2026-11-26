import EverydayContract
import Foundation
import Testing

@Suite("Corrective regression")
struct CorrectiveRegressionTests {
    // MARK: - Helpers

    private func makeEnvelope(
        payloadKind: PayloadKind,
        origin: MessageOrigin = .host,
        hostPosition: HostPosition? = nil,
        hostIdentity: HostIdentity? = nil,
        idempotencyKey: IdempotencyKey? = nil
    ) -> MessageEnvelope {
        MessageEnvelope(
            messageID: MessageID(rawValue: "msg-corrective")!,
            correlationID: CorrelationID(rawValue: "corr-corrective")!,
            sessionID: SessionID(rawValue: "session-corrective")!,
            hostIdentity: hostIdentity,
            hostPosition: hostPosition,
            payloadKind: payloadKind,
            idempotencyKey: idempotencyKey,
            origin: origin
        )
    }

    private func makeReference() -> ConversationMessageReference {
        ConversationMessageReference(
            messageID: ConversationMessageID(rawValue: "conversation-message-001")!,
            conversationID: ConversationID(rawValue: "conversation-001")!,
            channel: .client,
            receivedAt: Date(timeIntervalSince1970: 0),
            contentReferenceID: ContentReferenceID(rawValue: "content-001")!
        )
    }

    private func makePage(
        position: HostPosition,
        itemCount: Int
    ) -> ConversationPage {
        ConversationPage(
            conversationID: ConversationID(rawValue: "conversation-001")!,
            hostPosition: position,
            items: Array(repeating: makeReference(), count: itemCount)
        )
    }

    private func makeError() -> ErrorPayload {
        ErrorPayload(
            classification: .staleConsistency,
            code: "cursorGap",
            message: "The cursor is behind.",
            retry: .afterResynchronization
        )
    }

    private func responseMessage(
        envelope: MessageEnvelope,
        _ result: QueryResult
    ) -> ContractMessage {
        ContractMessage(envelope: envelope, payload: .response(.queryResult(result)))
    }

    private func synchronizationMessage(
        envelope: MessageEnvelope,
        _ response: SynchronizationResponse
    ) -> ContractMessage {
        ContractMessage(envelope: envelope, payload: .response(.synchronization(response)))
    }

    private func commandMessage(parameters: [String: JSONValue]) -> ContractMessage {
        ContractMessage(
            envelope: makeEnvelope(
                payloadKind: .request,
                origin: .client,
                idempotencyKey: IdempotencyKey(rawValue: "idem-corrective")!
            ),
            payload: .request(
                .command(
                    CommandRequest(
                        command: .pauseObjective,
                        target: .objective(ObjectiveID(rawValue: "objective-001")!),
                        parameters: parameters
                    )
                )
            )
        )
    }

    private func nest(_ value: JSONValue, containers: Int) -> JSONValue {
        var result = value
        for _ in 0..<containers {
            result = .array([result])
        }
        return result
    }

    private func commandJSON(containerDepth: Int) -> Data {
        let nested = String(repeating: "[", count: containerDepth) + "1"
            + String(repeating: "]", count: containerDepth)
        return Data("""
        {"envelope":{"messageID":"msg-nested","correlationID":"corr-nested","sessionID":"session-nested",\
        "protocolVersion":"1.0.0","schemaVersion":"1.0.0","payloadKind":"request",\
        "idempotencyKey":"idem-nested","origin":"client"},\
        "payload":{"kind":"request","value":{"kind":"command","value":{"command":"pauseObjective",\
        "target":{"kind":"objective","value":"objective-001"},\
        "parameters":{"nested":\(nested)}}}}}
        """.utf8)
    }

    private func nestObject(_ value: JSONValue, containers: Int) -> JSONValue {
        var result = value
        for _ in 0..<containers {
            result = .object(["n": result])
        }
        return result
    }

    private func commandJSONObject(containerDepth: Int) -> Data {
        let nested = String(repeating: "{\"n\":", count: containerDepth) + "1"
            + String(repeating: "}", count: containerDepth)
        return Data("""
        {"envelope":{"messageID":"msg-nested-object","correlationID":"corr-nested-object",\
        "sessionID":"session-nested-object","protocolVersion":"1.0.0","schemaVersion":"1.0.0",\
        "payloadKind":"request","idempotencyKey":"idem-nested-object","origin":"client"},\
        "payload":{"kind":"request","value":{"kind":"command","value":{"command":"pauseObjective",\
        "target":{"kind":"objective","value":"objective-001"},\
        "parameters":{"nested":\(nested)}}}}}
        """.utf8)
    }

    private func encodedParameterByteCount(_ parameters: [String: JSONValue]) throws -> Int {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(parameters).count
    }

    private func hostConditionMessage(detailLength: Int) -> ContractMessage {
        let condition = HostCondition(
            condition: .degraded,
            detail: String(repeating: "x", count: detailLength)
        )
        return ContractMessage(
            envelope: makeEnvelope(
                payloadKind: .event,
                hostPosition: HostPosition(77),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            payload: .event(.hostCondition(condition))
        )
    }

    // MARK: - M1: exact enum-case field sets

    @Test("SynchronizationOperation.open rejects position and accepts cursor")
    func openRejectsPosition() throws {
        let invalid = Data(#"{"kind":"open","projection":"tasks","cursor":41,"position":42}"#.utf8)
        #expect(throws: ContractDecodingError.self) {
            _ = try JSONDecoder().decode(SynchronizationOperation.self, from: invalid)
        }

        let valid = Data(#"{"kind":"open","projection":"tasks","cursor":41}"#.utf8)
        #expect(try JSONDecoder().decode(SynchronizationOperation.self, from: valid)
            == .open(projection: .tasks, cursor: HostPosition(41)))
    }

    @Test("SynchronizationOperation.applied rejects cursor and accepts position")
    func appliedRejectsCursor() throws {
        let invalid = Data(#"{"kind":"applied","projection":"tasks","position":42,"cursor":41}"#.utf8)
        #expect(throws: ContractDecodingError.self) {
            _ = try JSONDecoder().decode(SynchronizationOperation.self, from: invalid)
        }

        let valid = Data(#"{"kind":"applied","projection":"tasks","position":42}"#.utf8)
        #expect(try JSONDecoder().decode(SynchronizationOperation.self, from: valid)
            == .applied(projection: .tasks, position: HostPosition(42)))
    }

    @Test("ContractTarget.none rejects a value and accepts only its kind")
    func targetNoneRejectsValue() throws {
        let invalid = Data(#"{"kind":"none","value":"objective-001"}"#.utf8)
        #expect(throws: ContractDecodingError.self) {
            _ = try JSONDecoder().decode(ContractTarget.self, from: invalid)
        }

        let valid = Data(#"{"kind":"none"}"#.utf8)
        #expect(try JSONDecoder().decode(ContractTarget.self, from: valid) == ContractTarget.none)
    }

    // MARK: - M2: Host response identity and position semantics

    @Test("Conversation page responses require Host position and identity")
    func conversationPageRequiresHostState() throws {
        let page = makePage(position: HostPosition(7), itemCount: 1)

        let missingPosition = responseMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .conversationPage(page)
        )
        #expect(throws: ContractValidationError.missingHostPosition) {
            _ = try JSONContractCoder.encode(missingPosition)
        }

        let missingIdentity = responseMessage(
            envelope: makeEnvelope(payloadKind: .response, hostPosition: HostPosition(7)),
            .conversationPage(page)
        )
        #expect(throws: ContractValidationError.missingHostIdentity) {
            _ = try JSONContractCoder.encode(missingIdentity)
        }
    }

    @Test("Conversation page response position must agree with the envelope")
    func conversationPagePositionMustAgree() throws {
        let mismatched = responseMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(8),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .conversationPage(makePage(position: HostPosition(7), itemCount: 1))
        )
        #expect(throws: ContractValidationError.hostPositionMismatch) {
            _ = try JSONContractCoder.encode(mismatched)
        }

        let valid = responseMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(7),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .conversationPage(makePage(position: HostPosition(7), itemCount: 1))
        )
        #expect(try JSONContractCoder.encode(valid).isEmpty == false)
    }

    @Test("Content availability requires Host position and identity")
    func contentAvailabilityRequiresHostState() throws {
        let availability = ContentAvailability(
            contentReferenceID: ContentReferenceID(rawValue: "content-001")!,
            status: .available
        )
        let missing = responseMessage(
            envelope: makeEnvelope(payloadKind: .response),
            .contentAvailability(availability)
        )
        #expect(throws: ContractValidationError.missingHostPosition) {
            _ = try JSONContractCoder.encode(missing)
        }

        let missingIdentity = responseMessage(
            envelope: makeEnvelope(payloadKind: .response, hostPosition: HostPosition(9)),
            .contentAvailability(availability)
        )
        #expect(throws: ContractValidationError.missingHostIdentity) {
            _ = try JSONContractCoder.encode(missingIdentity)
        }

        let valid = responseMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(9),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .contentAvailability(availability)
        )
        #expect(try JSONContractCoder.encode(valid).isEmpty == false)
    }

    @Test("Positionless command results are allowed; reported positions must agree")
    func commandResultPositionSemantics() throws {
        let positionless = ContractMessage(
            envelope: makeEnvelope(payloadKind: .response),
            payload: .response(.commandResult(CommandResult(status: .rejected)))
        )
        #expect(try JSONContractCoder.encode(positionless).isEmpty == false)

        let missingHostState = ContractMessage(
            envelope: makeEnvelope(payloadKind: .response),
            payload: .response(
                .commandResult(CommandResult(status: .accepted, hostPosition: HostPosition(11)))
            )
        )
        #expect(throws: ContractValidationError.missingHostPosition) {
            _ = try JSONContractCoder.encode(missingHostState)
        }

        let mismatched = ContractMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(12),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            payload: .response(
                .commandResult(CommandResult(status: .accepted, hostPosition: HostPosition(11)))
            )
        )
        #expect(throws: ContractValidationError.hostPositionMismatch) {
            _ = try JSONContractCoder.encode(mismatched)
        }

        let missingIdentity = ContractMessage(
            envelope: makeEnvelope(payloadKind: .response, hostPosition: HostPosition(11)),
            payload: .response(
                .commandResult(CommandResult(status: .accepted, hostPosition: HostPosition(11)))
            )
        )
        #expect(throws: ContractValidationError.missingHostIdentity) {
            _ = try JSONContractCoder.encode(missingIdentity)
        }

        let valid = ContractMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(11),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            payload: .response(
                .commandResult(CommandResult(status: .accepted, hostPosition: HostPosition(11)))
            )
        )
        #expect(try JSONContractCoder.encode(valid).isEmpty == false)
    }

    @Test("Applied synchronization acknowledgement position must agree with the envelope")
    func appliedPositionMustAgree() throws {
        let missing = synchronizationMessage(
            envelope: makeEnvelope(payloadKind: .response),
            .applied(HostPosition(15))
        )
        #expect(throws: ContractValidationError.missingHostPosition) {
            _ = try JSONContractCoder.encode(missing)
        }

        let mismatched = synchronizationMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(16),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .applied(HostPosition(15))
        )
        #expect(throws: ContractValidationError.hostPositionMismatch) {
            _ = try JSONContractCoder.encode(mismatched)
        }

        let missingIdentity = synchronizationMessage(
            envelope: makeEnvelope(payloadKind: .response, hostPosition: HostPosition(15)),
            .applied(HostPosition(15))
        )
        #expect(throws: ContractValidationError.missingHostIdentity) {
            _ = try JSONContractCoder.encode(missingIdentity)
        }

        let valid = synchronizationMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(15),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .applied(HostPosition(15))
        )
        #expect(try JSONContractCoder.encode(valid).isEmpty == false)
    }

    @Test("Unavailable synchronization responses may be positionless")
    func unavailableMayBePositionless() throws {
        let message = synchronizationMessage(
            envelope: makeEnvelope(payloadKind: .response),
            .unavailable(makeError())
        )
        #expect(try JSONContractCoder.encode(message).isEmpty == false)
    }

    // MARK: - M3: projection and payload consistency

    @Test("Snapshot projection must match its payload case")
    func snapshotProjectionMustMatchPayload() throws {
        let page = makePage(position: HostPosition(5), itemCount: 1)
        let snapshot = ProjectionSnapshot(
            projection: .tasks,
            hostPosition: HostPosition(5),
            hostIdentity: HostIdentity(rawValue: "host-primary")!,
            payload: .conversations(page)
        )
        let message = synchronizationMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(5),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .snapshot(snapshot)
        )
        #expect(throws: ContractValidationError.projectionPayloadMismatch(projection: .tasks)) {
            _ = try JSONContractCoder.encode(message)
        }
    }

    @Test("Conversations snapshot position must match its nested page position")
    func conversationsSnapshotPositionMustMatchPage() throws {
        let snapshot = ProjectionSnapshot(
            projection: .conversations,
            hostPosition: HostPosition(6),
            hostIdentity: HostIdentity(rawValue: "host-primary")!,
            payload: .conversations(makePage(position: HostPosition(5), itemCount: 1))
        )
        let message = synchronizationMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(6),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .snapshot(snapshot)
        )
        #expect(throws: ContractValidationError.hostPositionMismatch) {
            _ = try JSONContractCoder.encode(message)
        }
    }

    @Test("Snapshot responses require and match Host identity")
    func snapshotIdentitySemantics() throws {
        let snapshot = ProjectionSnapshot(
            projection: .tasks,
            hostPosition: HostPosition(3),
            hostIdentity: HostIdentity(rawValue: "host-primary")!,
            payload: .tasks([])
        )

        let missingIdentity = synchronizationMessage(
            envelope: makeEnvelope(payloadKind: .response, hostPosition: HostPosition(3)),
            .snapshot(snapshot)
        )
        #expect(throws: ContractValidationError.missingHostIdentity) {
            _ = try JSONContractCoder.encode(missingIdentity)
        }

        let mismatchedIdentity = synchronizationMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(3),
                hostIdentity: HostIdentity(rawValue: "host-other")!
            ),
            .snapshot(snapshot)
        )
        #expect(throws: ContractValidationError.hostIdentityMismatch) {
            _ = try JSONContractCoder.encode(mismatchedIdentity)
        }

        let valid = synchronizationMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(3),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .snapshot(snapshot)
        )
        #expect(try JSONContractCoder.encode(valid).isEmpty == false)
    }

    @Test("Delta responses require committed Host state")
    func deltaRequiresHostState() {
        let delta = ProjectionDelta(
            projection: .tasks,
            fromPosition: HostPosition(1),
            toPosition: HostPosition(2),
            hostIdentity: HostIdentity(rawValue: "host-primary")!,
            changes: [.taskRemoved(ObjectiveID(rawValue: "objective-001")!)]
        )
        let missing = synchronizationMessage(
            envelope: makeEnvelope(payloadKind: .response),
            .delta(delta)
        )
        #expect(throws: ContractValidationError.missingHostPosition) {
            _ = try JSONContractCoder.encode(missing)
        }
    }

    @Test("Delta Host identity must match the envelope")
    func deltaHostIdentityMismatchIsRejected() throws {
        let hostIdentity = HostIdentity(rawValue: "host-primary")!
        let delta = ProjectionDelta(
            projection: .tasks,
            fromPosition: HostPosition(5),
            toPosition: HostPosition(6),
            hostIdentity: hostIdentity,
            changes: [.taskRemoved(ObjectiveID(rawValue: "objective-001")!)]
        )

        let mismatched = synchronizationMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(6),
                hostIdentity: HostIdentity(rawValue: "host-other")!
            ),
            .delta(delta)
        )
        #expect(throws: ContractValidationError.hostIdentityMismatch) {
            _ = try JSONContractCoder.encode(mismatched)
        }

        let valid = synchronizationMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(6),
                hostIdentity: hostIdentity
            ),
            .delta(delta)
        )
        #expect(try JSONContractCoder.encode(valid).isEmpty == false)
    }

    @Test("Approval changes in a delta must match toPosition")
    func deltaApprovalNoticePositionMustMatchToPosition() throws {
        let hostIdentity = HostIdentity(rawValue: "host-primary")!
        let approvalRequestID = ApprovalRequestID(rawValue: "approval-001")!

        func delta(noticePosition: HostPosition) -> ProjectionDelta {
            ProjectionDelta(
                projection: .approvals,
                fromPosition: HostPosition(5),
                toPosition: HostPosition(6),
                hostIdentity: hostIdentity,
                changes: [
                    .approvalAvailable(
                        ApprovalNotice(
                            approvalRequestID: approvalRequestID,
                            hostPosition: noticePosition,
                            isConsequential: true
                        )
                    )
                ]
            )
        }

        let mismatched = synchronizationMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(6),
                hostIdentity: hostIdentity
            ),
            .delta(delta(noticePosition: HostPosition(7)))
        )
        #expect(throws: ContractValidationError.hostPositionMismatch) {
            _ = try JSONContractCoder.encode(mismatched)
        }

        let valid = synchronizationMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(6),
                hostIdentity: hostIdentity
            ),
            .delta(delta(noticePosition: HostPosition(6)))
        )
        #expect(try JSONContractCoder.encode(valid).isEmpty == false)
    }

    @Test("Delta changes must belong to the declared projection")
    func deltaChangeMustBelongToProjection() throws {
        let delta = ProjectionDelta(
            projection: .tasks,
            fromPosition: HostPosition(5),
            toPosition: HostPosition(6),
            hostIdentity: HostIdentity(rawValue: "host-primary")!,
            changes: [.conversationMessageAppended(makeReference())]
        )
        let message = synchronizationMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(6),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .delta(delta)
        )
        #expect(throws: ContractValidationError.projectionChangeMismatch(projection: .tasks)) {
            _ = try JSONContractCoder.encode(message)
        }
    }

    @Test("Approval event position must match the envelope")
    func approvalEventPositionMustMatchEnvelope() throws {
        let notice = ApprovalNotice(
            approvalRequestID: ApprovalRequestID(rawValue: "approval-001")!,
            hostPosition: HostPosition(7),
            isConsequential: true
        )
        let message = ContractMessage(
            envelope: makeEnvelope(
                payloadKind: .event,
                hostPosition: HostPosition(8),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            payload: .event(.approvalAvailable(notice))
        )
        #expect(throws: ContractValidationError.hostPositionMismatch) {
            _ = try JSONContractCoder.encode(message)
        }

        let valid = ContractMessage(
            envelope: makeEnvelope(
                payloadKind: .event,
                hostPosition: HostPosition(7),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            payload: .event(.approvalAvailable(notice))
        )
        #expect(try JSONContractCoder.encode(valid).isEmpty == false)
    }

    @Test("Nested approval notice position in projection changed event must match envelope")
    func nestedApprovalNoticePositionInProjectionChangedEventMustMatchEnvelope() throws {
        let hostIdentity = HostIdentity(rawValue: "host-primary")!
        let notice = ApprovalNotice(
            approvalRequestID: ApprovalRequestID(rawValue: "approval-002")!,
            hostPosition: HostPosition(9),
            isConsequential: true
        )

        func message(envelopePosition: HostPosition) -> ContractMessage {
            ContractMessage(
                envelope: makeEnvelope(
                    payloadKind: .event,
                    hostPosition: envelopePosition,
                    hostIdentity: hostIdentity
                ),
                payload: .event(.projectionChanged(.approvalAvailable(notice)))
            )
        }

        #expect(throws: ContractValidationError.hostPositionMismatch) {
            _ = try JSONContractCoder.encode(message(envelopePosition: HostPosition(10)))
        }
        #expect(try JSONContractCoder.encode(message(envelopePosition: HostPosition(9))).isEmpty == false)
    }

    @Test("Host condition events round trip through the validated boundary")
    func hostConditionEventRoundTrips() throws {
        let condition = HostCondition(
            condition: .storagePressure,
            affectedObjectiveID: ObjectiveID(rawValue: "objective-001")!,
            detail: "Storage is constrained."
        )
        let message = ContractMessage(
            envelope: makeEnvelope(
                payloadKind: .event,
                hostPosition: HostPosition(31),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            payload: .event(.hostCondition(condition))
        )

        let decoded = try JSONContractCoder.decode(try JSONContractCoder.encode(message))
        #expect(decoded == message)
        guard case let .event(.hostCondition(decodedCondition)) = decoded.payload else {
            Issue.record("Expected a host condition event")
            return
        }
        #expect(decodedCondition == condition)
    }

    @Test("Channel condition events round trip through the validated boundary")
    func channelConditionEventRoundTrips() throws {
        let condition = ChannelCondition(
            channel: .messages,
            status: .degraded,
            detail: "Delivery is delayed."
        )
        let message = ContractMessage(
            envelope: makeEnvelope(
                payloadKind: .event,
                hostPosition: HostPosition(32),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            payload: .event(.channelCondition(condition))
        )

        let decoded = try JSONContractCoder.decode(try JSONContractCoder.encode(message))
        #expect(decoded == message)
        guard case let .event(.channelCondition(decodedCondition)) = decoded.payload else {
            Issue.record("Expected a channel condition event")
            return
        }
        #expect(decodedCondition == condition)
    }

    @Test("Recovery notice events round trip through the validated boundary")
    func recoveryNoticeEventRoundTrips() throws {
        let notice = RecoveryNotice(
            status: .parkedUncertainEffects,
            affectedObjectiveID: ObjectiveID(rawValue: "objective-002")!,
            detail: "Recovery is parked pending review."
        )
        let message = ContractMessage(
            envelope: makeEnvelope(
                payloadKind: .event,
                hostPosition: HostPosition(33),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            payload: .event(.recoveryNotice(notice))
        )

        let decoded = try JSONContractCoder.decode(try JSONContractCoder.encode(message))
        #expect(decoded == message)
        guard case let .event(.recoveryNotice(decodedNotice)) = decoded.payload else {
            Issue.record("Expected a recovery notice event")
            return
        }
        #expect(decodedNotice == notice)
    }

    @Test("Valid task and conversation snapshots still encode")
    func validSnapshotsEncode() throws {
        let tasks = ProjectionSnapshot(
            projection: .tasks,
            hostPosition: HostPosition(3),
            hostIdentity: HostIdentity(rawValue: "host-primary")!,
            payload: .tasks([])
        )
        let taskMessage = synchronizationMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(3),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .snapshot(tasks)
        )
        #expect(try JSONContractCoder.encode(taskMessage).isEmpty == false)

        let conversations = ProjectionSnapshot(
            projection: .conversations,
            hostPosition: HostPosition(3),
            hostIdentity: HostIdentity(rawValue: "host-primary")!,
            payload: .conversations(makePage(position: HostPosition(3), itemCount: 1))
        )
        let conversationMessage = synchronizationMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(3),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .snapshot(conversations)
        )
        #expect(try JSONContractCoder.encode(conversationMessage).isEmpty == false)
    }

    // MARK: - M4: validated boundary versus structural decoding

    @Test("Direct Codable decoding is structural and skips semantic validation")
    func directDecodingSkipsValidation() throws {
        let message = ContractMessage(
            envelope: makeEnvelope(payloadKind: .request, origin: .client),
            payload: .request(
                .command(
                    CommandRequest(
                        command: .pauseObjective,
                        target: .objective(ObjectiveID(rawValue: "objective-001")!),
                        parameters: [:]
                    )
                )
            )
        )

        let data = try JSONEncoder().encode(message)
        let structural = try JSONDecoder().decode(ContractMessage.self, from: data)
        #expect(structural.envelope.idempotencyKey == nil)

        #expect(throws: ContractValidationError.missingIdempotencyKey) {
            _ = try JSONContractCoder.decode(data)
        }
    }

    @Test("The validated boundary rejects oversized messages before parsing")
    func validatedBoundaryRejectsOversizedMessages() {
        let oversized = Data(repeating: 0x20, count: ContractLimits.maximumMessageBytes + 1)
        #expect(throws: ContractValidationError.messageTooLarge(
            bytes: ContractLimits.maximumMessageBytes + 1,
            maximum: ContractLimits.maximumMessageBytes
        )) {
            _ = try JSONContractCoder.decode(oversized)
        }
    }

    @Test("Host completion outcomes require Host state")
    func hostCompletionOutcomeRequiresHostState() throws {
        let acknowledgedMessageID = MessageID(rawValue: "msg-acknowledged")!
        let hostIdentity = HostIdentity(rawValue: "host-primary")!
        let positionless = AcknowledgementPayload(
            meaning: .completionOutcome,
            acknowledgedMessageID: acknowledgedMessageID
        )

        let missingPosition = ContractMessage(
            envelope: makeEnvelope(payloadKind: .acknowledgement, origin: .host),
            payload: .acknowledgement(positionless)
        )
        #expect(throws: ContractValidationError.missingHostPosition) {
            _ = try JSONContractCoder.encode(missingPosition)
        }

        let missingIdentity = ContractMessage(
            envelope: makeEnvelope(
                payloadKind: .acknowledgement,
                origin: .host,
                hostPosition: HostPosition(41)
            ),
            payload: .acknowledgement(
                AcknowledgementPayload(
                    meaning: .completionOutcome,
                    acknowledgedMessageID: acknowledgedMessageID,
                    hostPosition: HostPosition(41)
                )
            )
        )
        #expect(throws: ContractValidationError.missingHostIdentity) {
            _ = try JSONContractCoder.encode(missingIdentity)
        }

        let validHostOutcome = ContractMessage(
            envelope: makeEnvelope(
                payloadKind: .acknowledgement,
                origin: .host,
                hostPosition: HostPosition(41),
                hostIdentity: hostIdentity
            ),
            payload: .acknowledgement(
                AcknowledgementPayload(
                    meaning: .completionOutcome,
                    acknowledgedMessageID: acknowledgedMessageID,
                    hostPosition: HostPosition(41)
                )
            )
        )
        #expect(try JSONContractCoder.encode(validHostOutcome).isEmpty == false)

        let clientPositionless = ContractMessage(
            envelope: makeEnvelope(payloadKind: .acknowledgement, origin: .client),
            payload: .acknowledgement(positionless)
        )
        #expect(try JSONContractCoder.encode(clientPositionless).isEmpty == false)
    }

    @Test("Accepted message identifiers survive command result round trips")
    func acceptedMessageIDSurvivesCommandResultRoundTrip() throws {
        let acceptedMessageID = MessageID(rawValue: "msg-accepted-001")!
        let message = ContractMessage(
            envelope: makeEnvelope(payloadKind: .response),
            payload: .response(
                .commandResult(
                    CommandResult(status: .accepted, acceptedMessageID: acceptedMessageID)
                )
            )
        )

        let decoded = try JSONContractCoder.decode(try JSONContractCoder.encode(message))
        #expect(decoded == message)
        guard case let .response(.commandResult(result)) = decoded.payload else {
            Issue.record("Expected a command result response")
            return
        }
        #expect(result.acceptedMessageID == acceptedMessageID)
    }

    // MARK: - L2: JSONValue limits

    @Test("JSON nesting at the maximum is accepted programmatically and on decode")
    func jsonNestingAtMaximum() throws {
        let nested = nest(.int(1), containers: ContractLimits.maximumJSONNestingDepth)
        let message = commandMessage(parameters: ["nested": nested])
        #expect(try JSONContractCoder.encode(message).isEmpty == false)

        let decoded = try JSONContractCoder.decode(
            commandJSON(containerDepth: ContractLimits.maximumJSONNestingDepth)
        )
        #expect(decoded.envelope.payloadKind == .request)
    }

    @Test("JSON nesting one level beyond the maximum is rejected programmatically and on decode")
    func jsonNestingBeyondMaximum() {
        let nested = nest(.int(1), containers: ContractLimits.maximumJSONNestingDepth + 1)
        let message = commandMessage(parameters: ["nested": nested])
        #expect(throws: ContractValidationError.jsonNestingExceeded(
            maximum: ContractLimits.maximumJSONNestingDepth
        )) {
            _ = try JSONContractCoder.encode(message)
        }

        #expect(throws: ContractDecodingError.self) {
            _ = try JSONContractCoder.decode(
                commandJSON(containerDepth: ContractLimits.maximumJSONNestingDepth + 1)
            )
        }
    }

    @Test("Valid nested objects and arrays encode")
    func validNestedJSONValue() throws {
        let value: JSONValue = .object([
            "list": .array([.int(1), .object(["flag": .bool(true)])]),
            "text": .string("value")
        ])
        let message = commandMessage(parameters: ["structured": value])
        let data = try JSONContractCoder.encode(message)
        let decoded = try JSONContractCoder.decode(data)
        #expect(decoded == message)
    }

    @Test("Oversized command parameter data is rejected")
    func oversizedParameterData() {
        let message = commandMessage(parameters: ["text": .string(String(repeating: "x", count: 20_000))])
        #expect(throws: ContractValidationError.self) {
            _ = try JSONContractCoder.encode(message)
        }
    }

    @Test("Too many top-level command parameters are rejected")
    func tooManyParameters() {
        var parameters: [String: JSONValue] = [:]
        for index in 0...ContractLimits.maximumParameterCount {
            parameters["key\(index)"] = .int(Int64(index))
        }
        let message = commandMessage(parameters: parameters)
        #expect(throws: ContractValidationError.parameterCountExceeded(
            count: ContractLimits.maximumParameterCount + 1,
            maximum: ContractLimits.maximumParameterCount
        )) {
            _ = try JSONContractCoder.encode(message)
        }
    }

    @Test("Command parameter count boundary is inclusive at maximum")
    func parameterCountBoundaryIsInclusiveAtMaximum() throws {
        var parameters: [String: JSONValue] = [:]
        for index in 0..<ContractLimits.maximumParameterCount {
            parameters["key\(index)"] = .int(Int64(index))
        }
        #expect(try JSONContractCoder.encode(commandMessage(parameters: parameters)).isEmpty == false)

        parameters["overflow"] = .int(1)
        #expect(throws: ContractValidationError.parameterCountExceeded(
            count: ContractLimits.maximumParameterCount + 1,
            maximum: ContractLimits.maximumParameterCount
        )) {
            _ = try JSONContractCoder.encode(commandMessage(parameters: parameters))
        }
    }

    @Test("Command parameter byte boundary is inclusive at maximum")
    func parameterBytesBoundaryIsInclusiveAtMaximum() throws {
        let emptyTextBytes = try encodedParameterByteCount(["text": .string("")])
        let textLength = ContractLimits.maximumParameterBytes - emptyTextBytes
        let atMaximum: [String: JSONValue] = ["text": .string(String(repeating: "x", count: textLength))]
        #expect(try encodedParameterByteCount(atMaximum) == ContractLimits.maximumParameterBytes)
        #expect(try JSONContractCoder.encode(commandMessage(parameters: atMaximum)).isEmpty == false)

        let overMaximum: [String: JSONValue] = [
            "text": .string(String(repeating: "x", count: textLength + 1))
        ]
        #expect(throws: ContractValidationError.parameterBytesExceeded(
            bytes: ContractLimits.maximumParameterBytes + 1,
            maximum: ContractLimits.maximumParameterBytes
        )) {
            _ = try JSONContractCoder.encode(commandMessage(parameters: overMaximum))
        }
    }

    @Test("Object nesting boundary is inclusive at maximum")
    func objectNestingBoundaryIsInclusiveAtMaximum() throws {
        let atMaximum = nestObject(.int(1), containers: ContractLimits.maximumJSONNestingDepth)
        #expect(try JSONContractCoder.encode(
            commandMessage(parameters: ["nested": atMaximum])
        ).isEmpty == false)
        let decodedAtMaximum = try JSONContractCoder.decode(
            commandJSONObject(containerDepth: ContractLimits.maximumJSONNestingDepth)
        )
        #expect(decodedAtMaximum.envelope.payloadKind == .request)

        let overMaximum = nestObject(.int(1), containers: ContractLimits.maximumJSONNestingDepth + 1)
        #expect(throws: ContractValidationError.jsonNestingExceeded(
            maximum: ContractLimits.maximumJSONNestingDepth
        )) {
            _ = try JSONContractCoder.encode(commandMessage(parameters: ["nested": overMaximum]))
        }
        #expect(throws: ContractDecodingError.self) {
            _ = try JSONContractCoder.decode(
                commandJSONObject(containerDepth: ContractLimits.maximumJSONNestingDepth + 1)
            )
        }
    }

    @Test("Message size boundary is inclusive at maximum on encode")
    func messageSizeBoundaryIsInclusiveAtMaximum() throws {
        let baseCount = try JSONContractCoder.encode(hostConditionMessage(detailLength: 0)).count
        let detailLength = ContractLimits.maximumMessageBytes - baseCount
        let atMaximum = try JSONContractCoder.encode(hostConditionMessage(detailLength: detailLength))
        #expect(atMaximum.count == ContractLimits.maximumMessageBytes)

        #expect(throws: ContractValidationError.messageTooLarge(
            bytes: ContractLimits.maximumMessageBytes + 1,
            maximum: ContractLimits.maximumMessageBytes
        )) {
            _ = try JSONContractCoder.encode(hostConditionMessage(detailLength: detailLength + 1))
        }
    }

    @Test("Encode rejects messages that exceed the size limit")
    func encodeSideMessageSizeRejection() throws {
        func errorMessage(length: Int) -> ContractMessage {
            ContractMessage(
                envelope: makeEnvelope(payloadKind: .error),
                payload: .error(
                    ErrorPayload(
                        classification: .validation,
                        code: "validation",
                        message: String(repeating: "x", count: length),
                        retry: .none
                    )
                )
            )
        }

        let baseCount = try JSONContractCoder.encode(errorMessage(length: 1)).count
        let messageLength = ContractLimits.maximumMessageBytes + 1 - baseCount + 1
        #expect(messageLength > 1)
        #expect(throws: ContractValidationError.messageTooLarge(
            bytes: ContractLimits.maximumMessageBytes + 1,
            maximum: ContractLimits.maximumMessageBytes
        )) {
            _ = try JSONContractCoder.encode(errorMessage(length: messageLength))
        }
    }

    // MARK: - L4: response-side page limits

    @Test("Response conversation pages are bounded")
    func responsePageLimit() throws {
        let ordinary = responseMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(4),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .conversationPage(makePage(position: HostPosition(4), itemCount: 1))
        )
        #expect(try JSONContractCoder.encode(ordinary).isEmpty == false)

        let atMaximum = responseMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(4),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .conversationPage(
                makePage(position: HostPosition(4), itemCount: Int(ContractLimits.maximumPageSize))
            )
        )
        #expect(try JSONContractCoder.encode(atMaximum).isEmpty == false)

        let overMaximum = responseMessage(
            envelope: makeEnvelope(
                payloadKind: .response,
                hostPosition: HostPosition(4),
                hostIdentity: HostIdentity(rawValue: "host-primary")!
            ),
            .conversationPage(
                makePage(position: HostPosition(4), itemCount: Int(ContractLimits.maximumPageSize) + 1)
            )
        )
        #expect(throws: ContractValidationError.pageLimitExceeded(
            limit: ContractLimits.maximumPageSize + 1,
            maximum: ContractLimits.maximumPageSize
        )) {
            _ = try JSONContractCoder.encode(overMaximum)
        }
    }
}
