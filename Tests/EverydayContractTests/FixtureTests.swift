import EverydayContract
import Foundation
import Testing

@Suite("Contract fixture compatibility")
struct FixtureTests {
    @Test("All shipped fixtures decode and re-encode without field loss")
    func allFixturesRoundTrip() throws {
        let names = [
            "request-command",
            "response-snapshot",
            "event-projection",
            "error-stale",
            "sync-delta",
            "heartbeat",
            "acknowledgement"
        ]

        for name in names {
            let original = try fixtureData(name)
            let message = try JSONContractCoder.decode(original)
            let encoded = try JSONContractCoder.encode(message)
            #expect(try jsonObjectsEqual(original, encoded), "Fixture \(name) changed on re-encode")
        }
    }

    @Test("Command fixture carries an idempotency key and bounded intent parameters")
    func commandFixture() throws {
        let message = try fixtureMessage("request-command")
        #expect(message.envelope.payloadKind == .request)
        #expect(message.envelope.idempotencyKey?.rawValue == "idem-001")
        #expect(message.envelope.origin == .client)

        guard case let .request(.command(command)) = message.payload else {
            Issue.record("Expected a command request")
            return
        }
        #expect(command.command == .createObjective)
        #expect(command.target == ContractTarget.none)
        #expect(command.parameters["intent"] == .string("Prepare a summary"))
        #expect(command.parameters["priority"] == .int(2))
    }

    @Test("Snapshot fixture is Host-authored and positioned")
    func snapshotFixture() throws {
        let message = try fixtureMessage("response-snapshot")
        #expect(message.envelope.origin == .host)
        #expect(message.envelope.hostPosition == HostPosition(42))
        #expect(message.envelope.hostIdentity?.rawValue == "host-primary")

        guard case let .response(.synchronization(.snapshot(snapshot))) = message.payload else {
            Issue.record("Expected a synchronization snapshot")
            return
        }
        #expect(snapshot.projection == .tasks)
        #expect(snapshot.hostPosition == message.envelope.hostPosition)
        #expect(snapshot.hostIdentity == message.envelope.hostIdentity)
        guard case let .tasks(tasks) = snapshot.payload else {
            Issue.record("Expected a task snapshot")
            return
        }
        #expect(tasks.count == 1)
        #expect(tasks.first?.status == .active)
        #expect(tasks.first?.verificationState == .pending)
    }

    @Test("Projection event references content instead of embedding a body")
    func projectionEventFixture() throws {
        let message = try fixtureMessage("event-projection")
        #expect(message.envelope.payloadKind == .event)
        #expect(message.envelope.hostPosition == HostPosition(43))

        guard case let .event(.projectionChanged(.conversationMessageAppended(reference))) = message.payload else {
            Issue.record("Expected a conversation message projection event")
            return
        }
        #expect(reference.contentReferenceID.rawValue == "content-007")
        #expect(reference.channel == .messages)
        #expect(reference.senderHandle == "owner-handle")
    }

    @Test("Error fixture uses the stale-consistency classification")
    func errorFixture() throws {
        let message = try fixtureMessage("error-stale")
        guard case let .error(error) = message.payload else {
            Issue.record("Expected an error payload")
            return
        }
        #expect(error.classification == .staleConsistency)
        #expect(error.retry == .afterResynchronization)
        #expect(error.nextStep?.isEmpty == false)
    }

    @Test("Heartbeat fixture needs no session or device binding")
    func heartbeatFixture() throws {
        let message = try fixtureMessage("heartbeat")
        #expect(message.envelope.sessionID == nil)
        #expect(message.envelope.deviceID == nil)
        guard case let .heartbeat(heartbeat) = message.payload else {
            Issue.record("Expected a heartbeat payload")
            return
        }
        #expect(heartbeat.state == .live)
    }

    @Test("Acknowledgement meanings remain distinct")
    func acknowledgementFixture() throws {
        let message = try fixtureMessage("acknowledgement")
        guard case let .acknowledgement(acknowledgement) = message.payload else {
            Issue.record("Expected an acknowledgement payload")
            return
        }
        #expect(acknowledgement.meaning == .transportReceipt)
        #expect(acknowledgement.meaning != .hostAcceptance)
        #expect(acknowledgement.meaning != .completionOutcome)
    }
}
