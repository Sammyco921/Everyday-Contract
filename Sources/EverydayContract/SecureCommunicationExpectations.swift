import Foundation

public enum TransportSecurityLevel: String, Sendable {
    case tls13 = "TLS 1.3"
}

/// Contract-level expectations only. These constants describe what both applications must enforce
/// at their transport and session boundaries; this package performs no networking or cryptography.
///
/// `ContractValidator` can check message shape, origin, binding presence, Host positioning, and
/// idempotency presence. It cannot authenticate a peer, verify TLS, enroll a device, or authorize a
/// command. Consumers must not treat these constants as evidence that transport security exists.
public enum SecureCommunicationExpectations {
    public static let minimumTransportSecurity = TransportSecurityLevel.tls13
    public static let requiresEncryptedTransport = true
    public static let requiresAuthenticatedSessionOrDeviceBinding = true
    public static let requiresHostIdentityAndPositionForHostAuthoredState = true
    public static let requiresIdempotencyKeyForCommands = true
    public static let rejectsUnknownFields = true
    public static let maximumMessageBytes = ContractLimits.maximumMessageBytes

    /// Messages carry intent and Host-authored views. They never carry authority, approval, or
    /// permission grants, and a communication acknowledgement is never approval.
    public static let messagesCarryIntentNotAuthority = true
    public static let deliveryReceiptIsNotApproval = true
}
