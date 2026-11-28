import Foundation

/// A canonical, bounded statement describing the objective a Client asks the Host to create.
///
/// The stored value is canonical: NFC-normalized, trimmed, with internal whitespace runs collapsed
/// to one ASCII space. The original spelling is not retained because every consumer must see the
/// same bytes for validation, display, and replay comparisons.
public struct ObjectiveStatement: Codable, Hashable, Sendable, CustomStringConvertible {
    public static let maximumUnicodeScalars = ContractLimits.maximumObjectiveStatementUnicodeScalars
    public static let maximumUTF8Bytes = ContractLimits.maximumObjectiveStatementUTF8Bytes

    public let rawValue: String

    public init?(_ rawValue: String) {
        guard let canonical = try? Self.canonicalize(rawValue) else { return nil }
        self.rawValue = canonical
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        do {
            self.rawValue = try Self.canonicalize(value)
        } catch let error as StatementValidationError {
            throw ContractDecodingError.invalidObjectiveStatement(reason: error.reason)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var description: String { rawValue }

    private enum StatementValidationError: Error {
        case reason(String)

        var reason: String {
            switch self {
            case let .reason(value): return value
            }
        }
    }

    private static func canonicalize(_ value: String) throws -> String {
        let normalized = (value as NSString).precomposedStringWithCanonicalMapping

        // Whitespace controls are handled by trimming and collapsing. Every other C0/C1 control is
        // prohibited because it has no stable display meaning in a Client-authored statement.
        let prohibitedControls = CharacterSet.controlCharacters.subtracting(.whitespacesAndNewlines)
        guard normalized.unicodeScalars.allSatisfy({ !prohibitedControls.contains($0) }) else {
            throw StatementValidationError.reason("prohibited control character")
        }

        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw StatementValidationError.reason("statement is empty after trimming")
        }

        var canonical = ""
        canonical.reserveCapacity(trimmed.count)
        var previousWasWhitespace = false
        for scalar in trimmed.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                if !previousWasWhitespace {
                    canonical.append(" ")
                }
                previousWasWhitespace = true
            } else {
                canonical.unicodeScalars.append(scalar)
                previousWasWhitespace = false
            }
        }

        let scalarCount = canonical.unicodeScalars.count
        guard scalarCount <= maximumUnicodeScalars else {
            throw StatementValidationError.reason(
                "Unicode scalar count \(scalarCount) exceeds \(maximumUnicodeScalars)"
            )
        }
        let byteCount = canonical.utf8.count
        guard byteCount <= maximumUTF8Bytes else {
            throw StatementValidationError.reason(
                "UTF-8 byte length \(byteCount) exceeds \(maximumUTF8Bytes)"
            )
        }
        return canonical
    }
}
