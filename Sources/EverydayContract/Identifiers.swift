import Foundation

/// Bounds applied to contract-level messages. These are protocol limits, not transport tuning knobs.
public enum ContractLimits {
    public static let maximumMessageBytes = 1_048_576
    public static let maximumIdentifierLength = 256
    public static let maximumErrorCodeLength = 128
    public static let maximumPageSize: UInt32 = 500
    public static let maximumParameterCount = 64
    public static let maximumParameterBytes = 16_384
    /// Maximum number of nested arrays or objects in a `JSONValue`. A scalar has depth zero.
    public static let maximumJSONNestingDepth = 32

    /// Maximum UTF-8 byte length of one conversation message body. This bounds the body itself;
    /// the complete encoded `ContractMessage` must still satisfy `maximumMessageBytes`.
    public static let maximumConversationMessageBodyUTF8Bytes = 1_048_576

    /// Maximum Unicode scalars in one conversation message body. This is one half of the UTF-8
    /// ceiling, so the byte and scalar ceilings are independently enforceable: dense multibyte text
    /// is rejected by the byte ceiling, while long single-byte text is rejected by this ceiling.
    public static let maximumConversationMessageBodyUnicodeScalars =
        maximumConversationMessageBodyUTF8Bytes / 2

    /// Maximum Unicode scalars in one canonical objective statement.
    public static let maximumObjectiveStatementUnicodeScalars = 512

    /// Maximum UTF-8 bytes in one canonical objective statement.
    public static let maximumObjectiveStatementUTF8Bytes = 2_048
}

/// Marker protocol for Host-owned or session-owned identifiers carried in the shared contract.
public protocol ContractIdentifierKind {
    static var displayName: String { get }
}

/// A non-empty, length-bounded identifier with a distinct nominal type per domain.
public struct ContractIdentifier<Kind: ContractIdentifierKind>: RawRepresentable, Codable, Hashable,
    Sendable, CustomStringConvertible {
    public let rawValue: String

    public init?(rawValue: String) {
        guard !rawValue.isEmpty, rawValue.count <= ContractLimits.maximumIdentifierLength else {
            return nil
        }
        self.rawValue = rawValue
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        guard let identifier = Self(rawValue: value) else {
            throw ContractDecodingError.invalidIdentifier(type: Kind.displayName)
        }
        self = identifier
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }
}

public enum MessageIDKind: ContractIdentifierKind { public static let displayName = "message identifier" }
public enum CorrelationIDKind: ContractIdentifierKind { public static let displayName = "correlation identifier" }
public enum CausationIDKind: ContractIdentifierKind { public static let displayName = "causation identifier" }
public enum SessionIDKind: ContractIdentifierKind { public static let displayName = "session identifier" }
public enum DeviceIDKind: ContractIdentifierKind { public static let displayName = "device identifier" }
public enum HostIdentityKind: ContractIdentifierKind { public static let displayName = "Host identity" }
public enum IdempotencyKeyKind: ContractIdentifierKind { public static let displayName = "idempotency key" }
public enum ApprovalRequestIDKind: ContractIdentifierKind { public static let displayName = "approval request identifier" }
public enum ObjectiveIDKind: ContractIdentifierKind { public static let displayName = "objective identifier" }
public enum RunIDKind: ContractIdentifierKind { public static let displayName = "run identifier" }
public enum WorkItemIDKind: ContractIdentifierKind { public static let displayName = "work item identifier" }
public enum ConversationIDKind: ContractIdentifierKind { public static let displayName = "conversation identifier" }
public enum ConversationMessageIDKind: ContractIdentifierKind { public static let displayName = "conversation message identifier" }
public enum ContentReferenceIDKind: ContractIdentifierKind { public static let displayName = "content reference identifier" }

public typealias MessageID = ContractIdentifier<MessageIDKind>
public typealias CorrelationID = ContractIdentifier<CorrelationIDKind>
public typealias CausationID = ContractIdentifier<CausationIDKind>
public typealias SessionID = ContractIdentifier<SessionIDKind>
public typealias DeviceID = ContractIdentifier<DeviceIDKind>
public typealias HostIdentity = ContractIdentifier<HostIdentityKind>
public typealias IdempotencyKey = ContractIdentifier<IdempotencyKeyKind>
public typealias ApprovalRequestID = ContractIdentifier<ApprovalRequestIDKind>
public typealias ObjectiveID = ContractIdentifier<ObjectiveIDKind>
public typealias RunID = ContractIdentifier<RunIDKind>
public typealias WorkItemID = ContractIdentifier<WorkItemIDKind>
public typealias ConversationID = ContractIdentifier<ConversationIDKind>
public typealias ConversationMessageID = ContractIdentifier<ConversationMessageIDKind>
public typealias ContentReferenceID = ContractIdentifier<ContentReferenceIDKind>

/// The Host-assigned committed position used to order projections and synchronize derived views.
public struct HostPosition: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let value: UInt64

    public init(_ value: UInt64) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(try container.decode(UInt64.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    public static func < (lhs: HostPosition, rhs: HostPosition) -> Bool {
        lhs.value < rhs.value
    }

    public var description: String { String(value) }
}

/// Coding information used to bound recursive `JSONValue` decoding. The budget is injected by
/// `JSONContractCoder`; direct structural `Codable` decoding does not receive it and therefore does
/// not enforce the depth limit.
let contractJSONValueDepthKey = CodingUserInfoKey(rawValue: "EverydayContract.jsonValueDepth")!

/// Mutable depth counter scoped to a single decode invocation. `@unchecked Sendable` is safe here
/// because `JSONContractCoder` creates one instance per decode and does not share it across tasks.
final class JSONValueDecodingBudget: @unchecked Sendable {
    var containerDepth = 0
}

/// A bounded JSON value used only for explicitly declared, Host-validated command and result metadata.
/// It is not a general-purpose shelter for authority or application state.
///
/// Nesting is limited by `ContractLimits.maximumJSONNestingDepth` on the validated decoding path and
/// during `ContractValidator` checks.
public indirect enum JSONValue: Codable, Hashable, Sendable {
    case null
    case bool(Bool)
    case int(Int64)
    case double(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .int(value)
        } else if let value = try? container.decode(Double.self) {
            guard value.isFinite else {
                throw ContractDecodingError.invalidJSONValue("non-finite number")
            }
            self = .double(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else {
            self = try Self.decodeContainer(from: container, decoder: decoder)
        }
    }

    private static func decodeContainer(
        from container: SingleValueDecodingContainer,
        decoder: Decoder
    ) throws -> JSONValue {
        let budget = decoder.userInfo[contractJSONValueDepthKey] as? JSONValueDecodingBudget
        budget?.containerDepth += 1
        defer { budget?.containerDepth -= 1 }
        if let budget, budget.containerDepth > ContractLimits.maximumJSONNestingDepth {
            throw ContractDecodingError.jsonNestingTooDeep(
                maximum: ContractLimits.maximumJSONNestingDepth
            )
        }

        do {
            return .array(try container.decode([JSONValue].self))
        } catch let error as ContractDecodingError {
            throw error
        } catch {
            // The value is not an array; try an object next.
        }

        do {
            return .object(try container.decode([String: JSONValue].self))
        } catch let error as ContractDecodingError {
            throw error
        } catch {
            throw ContractDecodingError.invalidJSONValue("unsupported value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(value):
            try container.encode(value)
        case let .int(value):
            try container.encode(value)
        case let .double(value):
            guard value.isFinite else {
                throw ContractDecodingError.invalidJSONValue("non-finite number")
            }
            try container.encode(value)
        case let .string(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        }
    }

    /// Maximum nested container depth. A scalar is zero; an empty array or object is one.
    /// Measured iteratively so validation cannot recurse without bound on a hostile value.
    var nestingDepth: Int {
        var maximum = 0
        var stack: [(JSONValue, Int)] = [(self, 0)]
        while let (value, depth) = stack.popLast() {
            switch value {
            case let .array(items):
                maximum = Swift.max(maximum, depth + 1)
                stack.append(contentsOf: items.map { ($0, depth + 1) })
            case let .object(object):
                maximum = Swift.max(maximum, depth + 1)
                stack.append(contentsOf: object.values.map { ($0, depth + 1) })
            case .null, .bool, .int, .double, .string:
                break
            }
        }
        return maximum
    }
}
