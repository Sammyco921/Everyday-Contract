import Foundation

/// Errors produced while decoding the shared JSON contract.
public enum ContractDecodingError: Error, Equatable, LocalizedError {
    case unknownFields(type: String, fields: [String])
    case invalidFieldsForCase(type: String, fields: [String])
    case invalidIdentifier(type: String)
    case invalidSemanticVersion(String)
    case invalidJSONValue(String)
    case jsonNestingTooDeep(maximum: Int)

    public var errorDescription: String? {
        switch self {
        case let .unknownFields(type, fields):
            return "Unknown field(s) for \(type): \(fields.joined(separator: ", "))."
        case let .invalidFieldsForCase(type, fields):
            return "Field(s) not permitted for \(type): \(fields.joined(separator: ", "))."
        case let .invalidIdentifier(type):
            return "Invalid or empty \(type)."
        case let .invalidSemanticVersion(value):
            return "Invalid semantic version: \(value)."
        case let .invalidJSONValue(reason):
            return "Invalid JSON value: \(reason)."
        case let .jsonNestingTooDeep(maximum):
            return "JSON nesting exceeds the maximum depth of \(maximum)."
        }
    }
}

/// Returns a keyed container after rejecting any field that is not part of the declared schema.
///
/// The Host and Client must not silently reinterpret an unknown field as authoritative. Rejecting
/// unknown fields during decode makes additive changes explicit: a receiver must update its schema
/// before it can accept a new field.
private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}

func strictContainer<Keys: CodingKey & CaseIterable>(
    _ keyType: Keys.Type,
    from decoder: Decoder,
    type: String
) throws -> KeyedDecodingContainer<Keys> {
    // A typed keyed container only exposes keys that map to a declared CodingKey case. Inspect a
    // dynamic container first so unrecognized field names are visible and can be rejected.
    let dynamic = try decoder.container(keyedBy: DynamicCodingKey.self)
    let allowed = Set(Keys.allCases.map(\.stringValue))
    let actual = Set(dynamic.allKeys.map(\.stringValue))
    let unknown = actual.subtracting(allowed)
    guard unknown.isEmpty else {
        throw ContractDecodingError.unknownFields(type: type, fields: unknown.sorted())
    }
    return try decoder.container(keyedBy: Keys.self)
}

/// Rejects declared fields that are not permitted for the specific case selected by a tagged enum.
///
/// `strictContainer` rejects names that the type does not declare at all. This second check handles
/// names that the type declares for other cases but that are meaningless for the selected case, such
/// as `position` on `SynchronizationOperation.open`.
func rejectFieldsOutsideCase<Keys: CodingKey & CaseIterable>(
    _ keyType: Keys.Type,
    from decoder: Decoder,
    type: String,
    allowed: Set<String>
) throws {
    let dynamic = try decoder.container(keyedBy: DynamicCodingKey.self)
    let actual = Set(dynamic.allKeys.map(\.stringValue))
    let invalid = actual.subtracting(allowed)
    guard invalid.isEmpty else {
        throw ContractDecodingError.invalidFieldsForCase(type: type, fields: invalid.sorted())
    }
}
