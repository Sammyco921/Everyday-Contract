import EverydayContract
import Foundation
import Testing

@Suite("Objective creation wire contract")
struct ObjectiveCreationTests {
    private func makeStatement(_ value: String = "Prepare a summary") -> ObjectiveStatement {
        ObjectiveStatement(value)!
    }

    private func makeEnvelope(
        idempotencyKey: IdempotencyKey? = IdempotencyKey(rawValue: "idem-objective")!,
        includeHostState: Bool = false
    ) -> MessageEnvelope {
        MessageEnvelope(
            messageID: MessageID(rawValue: "msg-objective")!,
            correlationID: CorrelationID(rawValue: "corr-objective")!,
            sessionID: SessionID(rawValue: "session-objective")!,
            hostIdentity: includeHostState ? HostIdentity(rawValue: "host-primary")! : nil,
            hostPosition: includeHostState ? HostPosition(9) : nil,
            payloadKind: .request,
            idempotencyKey: idempotencyKey,
            origin: .client
        )
    }

    private func makeMessage(
        target: ContractTarget? = ContractTarget.none,
        parameters: [String: JSONValue] = [:],
        payload: CommandPayload? = nil,
        idempotencyKey: IdempotencyKey? = IdempotencyKey(rawValue: "idem-objective")!,
        includeHostState: Bool = false
    ) -> ContractMessage {
        ContractMessage(
            envelope: makeEnvelope(
                idempotencyKey: idempotencyKey,
                includeHostState: includeHostState
            ),
            payload: .request(
                .command(
                    CommandRequest(
                        command: .createObjective,
                        target: target,
                        parameters: parameters,
                        payload: payload
                    )
                )
            )
        )
    }

    private func validCreationMessage() -> ContractMessage {
        makeMessage(
            payload: .objectiveCreation(
                ObjectiveCreation(statement: makeStatement())
            )
        )
    }

    private func modifiedFixture(_ name: String, _ changes: [(String, String)]) throws -> Data {
        let string = String(data: try fixtureData(name), encoding: .utf8)!
        var modified = string
        for (needle, replacement) in changes {
            #expect(modified.contains(needle), "Fixture edit target was not found: \(needle)")
            modified = modified.replacingOccurrences(of: needle, with: replacement)
        }
        return Data(modified.utf8)
    }

    // MARK: - ObjectiveStatement

    @Test("Objective statements normalize Unicode and whitespace")
    func statementCanonicalization() throws {
        let statement = makeStatement("  Cafe\u{301}\t is   ready \n")
        #expect(statement.rawValue == "Café is ready")

        let data = try JSONContractCoder.encode(
            makeMessage(
                payload: .objectiveCreation(
                    ObjectiveCreation(statement: statement)
                )
            )
        )
        #expect(try JSONContractCoder.decode(data) ==
            makeMessage(
                payload: .objectiveCreation(
                    ObjectiveCreation(statement: makeStatement("Café is ready"))
                )
            ))
    }

    @Test("Objective statements reject blank text and prohibited controls")
    func statementRejectsBlankTextAndControls() {
        #expect(ObjectiveStatement("") == nil)
        #expect(ObjectiveStatement(" \n\t ") == nil)
        #expect(ObjectiveStatement("before\u{0000}after") == nil)
        #expect(ObjectiveStatement("before\u{0080}after") == nil)

        let encodedControl = Data(#""a\u0000b""#.utf8)
        #expect(throws: ContractDecodingError.self) {
            _ = try JSONDecoder().decode(ObjectiveStatement.self, from: encodedControl)
        }
    }

    @Test("Objective statement scalar and byte limits are inclusive")
    func statementBoundaries() {
        #expect(ObjectiveStatement.maximumUnicodeScalars == 512)
        #expect(ObjectiveStatement.maximumUTF8Bytes == 2_048)

        let scalarsAtMaximum = String(repeating: "a", count: 512)
        let scalarsOverMaximum = String(repeating: "a", count: 513)
        #expect(ObjectiveStatement(scalarsAtMaximum)?.rawValue == scalarsAtMaximum)
        #expect(ObjectiveStatement(scalarsOverMaximum) == nil)

        let bytesAtMaximum = String(repeating: "\u{10000}", count: 512)
        let bytesOverMaximum = String(repeating: "\u{10000}", count: 513)
        #expect(bytesAtMaximum.utf8.count == ObjectiveStatement.maximumUTF8Bytes)
        #expect(ObjectiveStatement(bytesAtMaximum)?.rawValue == bytesAtMaximum)
        #expect(ObjectiveStatement(bytesOverMaximum) == nil)
    }

    @Test("Objective creation rejects unknown fields in its typed payload")
    func objectiveCreationRejectsUnknownFields() {
        let invalid = Data(#"{"statement":"Hello","future":true}"#.utf8)
        #expect(throws: ContractDecodingError.self) {
            _ = try JSONDecoder().decode(ObjectiveCreation.self, from: invalid)
        }
    }

    // MARK: - Typed createObjective request

    @Test("Typed createObjective request round-trips through the validated boundary")
    func typedCreationRoundTrip() throws {
        let message = validCreationMessage()
        let data = try JSONContractCoder.encode(message)
        let decoded = try JSONContractCoder.decode(data)
        #expect(decoded == message)

        guard case let .request(.command(command)) = decoded.payload,
              case let .objectiveCreation(creation)? = command.payload else {
            Issue.record("Expected a typed objective creation payload")
            return
        }
        #expect(command.command == .createObjective)
        #expect(command.target == ContractTarget.none)
        #expect(command.parameters.isEmpty)
        #expect(creation.statement.rawValue == "Prepare a summary")
        #expect(decoded.envelope.idempotencyKey?.rawValue == "idem-objective")
    }

    @Test("createObjective requires its typed payload and a none target")
    func typedCreationRequiresValidShape() throws {
        #expect(throws: ContractValidationError.missingCommandPayload(.createObjective)) {
            _ = try JSONContractCoder.encode(makeMessage())
        }
        #expect(throws: ContractValidationError.unexpectedCommandPayload(.createObjective)) {
            _ = try JSONContractCoder.encode(
                makeMessage(
                    payload: .conversationMessageSubmission(
                        ConversationMessageSubmission(
                            conversationID: ConversationID(rawValue: "conversation-001")!,
                            body: ConversationMessageBody("Hello")!
                        )
                    )
                )
            )
        }
        #expect(throws: ContractValidationError.missingObjectiveCreationTarget) {
            _ = try JSONContractCoder.encode(
                makeMessage(
                    target: nil,
                    payload: .objectiveCreation(
                        ObjectiveCreation(statement: makeStatement())
                    )
                )
            )
        }
        #expect(throws: ContractValidationError.invalidObjectiveCreationTarget) {
            _ = try JSONContractCoder.encode(
                makeMessage(
                    target: .conversation(ConversationID(rawValue: "conversation-001")!),
                    payload: .objectiveCreation(
                        ObjectiveCreation(statement: makeStatement())
                    )
                )
            )
        }
    }

    @Test("createObjective forbids generic parameters, missing keys, and Client Host state")
    func typedCreationRejectsSmuggledAuthority() throws {
        let creation = ObjectiveCreation(statement: makeStatement())
        #expect(throws: ContractValidationError.commandParametersNotAllowed(.createObjective)) {
            _ = try JSONContractCoder.encode(
                makeMessage(
                    parameters: ["statement": .string("smuggled")],
                    payload: .objectiveCreation(creation)
                )
            )
        }
        #expect(throws: ContractValidationError.missingIdempotencyKey) {
            _ = try JSONContractCoder.encode(
                makeMessage(payload: .objectiveCreation(creation), idempotencyKey: nil)
            )
        }
        #expect(throws: ContractValidationError.clientCommandCarriesHostState) {
            _ = try JSONContractCoder.encode(
                makeMessage(payload: .objectiveCreation(creation), includeHostState: true)
            )
        }
    }

    @Test("1.1.0 messages are refused by the exact 1.2.0 profile")
    func olderProtocolVersionIsRefused() throws {
        let oldProtocol = try modifiedFixture("request-command", [
            ("\"protocolVersion\": \"1.2.0\"", "\"protocolVersion\": \"1.1.0\"")
        ])
        #expect(throws: ContractValidationError.unsupportedProtocolVersion(
            SemanticVersion(major: 1, minor: 1, patch: 0)
        )) {
            _ = try JSONContractCoder.decode(oldProtocol)
        }
    }

    // MARK: - Typed creation result

    @Test("Generic and typed command result representations are mutually exclusive")
    func commandResultRepresentationsAreExclusive() throws {
        let typed = CommandResult(
            status: .completed,
            result: ["legacy": .bool(true)],
            typedResult: .objectiveCreation(
                ObjectiveCreationResult(
                    createdObjectiveID: ObjectiveID(rawValue: "objective-001")!
                )
            )
        )
        let envelope = MessageEnvelope(
            messageID: MessageID(rawValue: "msg-result-conflict")!,
            correlationID: CorrelationID(rawValue: "corr-result-conflict")!,
            sessionID: SessionID(rawValue: "session-result-conflict")!,
            payloadKind: .response,
            origin: .host
        )
        #expect(throws: ContractValidationError.commandResultRepresentationConflict) {
            _ = try JSONContractCoder.encode(
                ContractMessage(
                    envelope: envelope,
                    payload: .response(.commandResult(typed))
                )
            )
        }

        let invalidData = try modifiedFixture("response-command-result", [
            ("\"typedResult\"", "\"result\":{\"legacy\":true},\"typedResult\"")
        ])
        #expect(throws: ContractDecodingError.self) {
            _ = try JSONContractCoder.decode(invalidData)
        }
    }

    @Test("Generic command results still round-trip")
    func genericCommandResultStillRoundTrips() throws {
        let result = CommandResult(status: .completed, result: ["accepted": .bool(true)])
        let envelope = MessageEnvelope(
            messageID: MessageID(rawValue: "msg-generic-result")!,
            correlationID: CorrelationID(rawValue: "corr-generic-result")!,
            sessionID: SessionID(rawValue: "session-generic-result")!,
            payloadKind: .response,
            origin: .host
        )
        let message = ContractMessage(
            envelope: envelope,
            payload: .response(.commandResult(result))
        )
        #expect(try JSONContractCoder.decode(JSONContractCoder.encode(message)) == message)
    }
}
