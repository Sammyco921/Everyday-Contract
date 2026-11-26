import EverydayContract
import Testing

@Suite("Contract-only surface")
struct ContractSurfaceTests {
    @Test("Secure expectations remain contract-level")
    func secureExpectations() {
        #expect(SecureCommunicationExpectations.minimumTransportSecurity == .tls13)
        #expect(SecureCommunicationExpectations.requiresEncryptedTransport)
        #expect(SecureCommunicationExpectations.requiresAuthenticatedSessionOrDeviceBinding)
        #expect(SecureCommunicationExpectations.requiresHostIdentityAndPositionForHostAuthoredState)
        #expect(SecureCommunicationExpectations.requiresIdempotencyKeyForCommands)
        #expect(SecureCommunicationExpectations.rejectsUnknownFields)
        #expect(SecureCommunicationExpectations.messagesCarryIntentNotAuthority)
        #expect(SecureCommunicationExpectations.deliveryReceiptIsNotApproval)
        #expect(SecureCommunicationExpectations.maximumMessageBytes == ContractLimits.maximumMessageBytes)
    }

    @Test("All approved Client command intents have a shared representation")
    func commandKinds() {
        let commands: [CommandKind] = [
            .createObjective,
            .modifyObjective,
            .pauseObjective,
            .resumeObjective,
            .cancelObjective,
            .redirectObjective,
            .answerClarification,
            .submitApprovalDecision,
            .narrowGrant,
            .revokeGrant,
            .changeSetting,
            .configureChannel,
            .revokeDevice
        ]
        #expect(commands.count == 13)
        #expect(Set(commands.map(\.rawValue)).count == 13)
    }

    @Test("Error classes match the approved reporting taxonomy")
    func errorClasses() {
        let classes: [ErrorClass] = [
            .transport,
            .authentication,
            .authorization,
            .staleConsistency,
            .validation,
            .hostCondition,
            .channelCondition
        ]
        #expect(classes.count == 7)
        #expect(Set(classes.map(\.rawValue)).count == 7)
    }

    @Test("Connection states preserve the synchronization lifecycle")
    func connectionStates() {
        #expect(ConnectionState.allCases.map(\.rawValue) == [
            "disconnected",
            "connecting",
            "authenticating",
            "synchronizing",
            "live",
            "degraded",
            "closing"
        ])
    }
}
