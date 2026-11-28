import EverydayContract
import Foundation
import Testing

@Suite("Task and conversation synchronization contracts")
struct SynchronizationTests {
    @Test("A delta advances Host position and identifies its changes")
    func deltaAdvancesPosition() throws {
        let message = try fixtureMessage("sync-delta")
        guard case let .response(.synchronization(.delta(delta))) = message.payload else {
            Issue.record("Expected a synchronization delta")
            return
        }

        #expect(delta.fromPosition == HostPosition(42))
        #expect(delta.toPosition == HostPosition(45))
        #expect(delta.fromPosition < delta.toPosition)
        #expect(message.envelope.hostPosition == delta.toPosition)
        #expect(delta.hostIdentity == message.envelope.hostIdentity)
        #expect(delta.changes.count == 1)

        guard case let .taskUpserted(task) = delta.changes.first else {
            Issue.record("Expected a task upsert change")
            return
        }
        #expect(task.objectiveID.rawValue == "objective-001")
        #expect(task.objectiveVersion == 2)
        #expect(task.statement.rawValue == "Prepare a summary")
        #expect(task.status == .verifying)
        #expect(task.completedWorkItemCount == 3)
        #expect(task.remainingWorkItemCount == 0)
    }

    @Test("Draft is an available display-level task status")
    func draftStatusIsAvailable() {
        #expect(TaskStatus.draft.rawValue == "draft")
        #expect(TaskStatus.allCases.contains(.draft))
    }

    @Test("Task snapshots and deltas require a statement field")
    func taskViewsRequireStatement() throws {
        for name in ["response-snapshot", "sync-delta"] {
            let original = String(data: try fixtureData(name), encoding: .utf8)!
            let needle = "\"statement\": \"Prepare a summary\",\n"
            #expect(original.contains(needle), "Fixture \(name) lacks a statement field")
            let withoutStatement = original.replacingOccurrences(of: needle, with: "")
            #expect(throws: DecodingError.self) {
                _ = try JSONContractCoder.decode(Data(withoutStatement.utf8))
            }
        }
    }

    @Test("Repeated delivery of the same positioned delta is structurally identical")
    func repeatedDeltaIsIdentical() throws {
        let first = try fixtureMessage("sync-delta")
        let second = try fixtureMessage("sync-delta")
        #expect(first == second)
        #expect(try JSONContractCoder.canonicalData(for: first) ==
            JSONContractCoder.canonicalData(for: second))
    }

    @Test("A Client sends a cursor and never sends projection truth")
    func clientSendsCursorOnly() throws {
        let envelope = MessageEnvelope(
            messageID: MessageID(rawValue: "msg-sync-open")!,
            correlationID: CorrelationID(rawValue: "corr-sync-open")!,
            sessionID: SessionID(rawValue: "session-sync")!,
            payloadKind: .request,
            origin: .client
        )
        let request = SynchronizationRequest(
            operation: .open(projection: .conversations, cursor: HostPosition(41))
        )
        let message = ContractMessage(
            envelope: envelope,
            payload: .request(.synchronize(request))
        )

        #expect(try JSONContractCoder.encode(message).isEmpty == false)
        guard case let .request(.synchronize(sync)) = message.payload,
              case let .open(projection, cursor) = sync.operation else {
            Issue.record("Expected a synchronization open request")
            return
        }
        #expect(projection == .conversations)
        #expect(cursor == HostPosition(41))
        #expect(envelope.hostPosition == nil)
    }

    @Test("Snapshots carry Host identity and replace a derived view")
    func snapshotCarriesHostIdentity() throws {
        let message = try fixtureMessage("response-snapshot")
        guard case let .response(.synchronization(.snapshot(snapshot))) = message.payload else {
            Issue.record("Expected a synchronization snapshot")
            return
        }
        #expect(snapshot.projection == .tasks)
        #expect(snapshot.hostIdentity.rawValue == "host-primary")
        #expect(snapshot.hostPosition.value > 0)
    }
}
