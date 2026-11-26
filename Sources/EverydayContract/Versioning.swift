import Foundation

public enum ContractVersionError: Error, Equatable, LocalizedError {
    case malformed(String)
    case rangeInverted

    public var errorDescription: String? {
        switch self {
        case let .malformed(value):
            return "Malformed semantic version: \(value)."
        case .rangeInverted:
            return "Protocol range minimum must not exceed maximum."
        }
    }
}

/// A SemVer value used for package, protocol, and schema versions.
///
/// The supported grammar is the strict numeric triple `major.minor.patch`. Prerelease and build
/// metadata (`-alpha`, `+build.5`) are not currently supported. Components are unsigned integers
/// without leading zeros.
public struct SemanticVersion: Codable, Hashable, Comparable, Sendable, CustomStringConvertible {
    public let major: UInt64
    public let minor: UInt64
    public let patch: UInt64

    public init(major: UInt64, minor: UInt64, patch: UInt64) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public init(string: String) throws {
        let parts = string.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else {
            throw ContractVersionError.malformed(string)
        }
        let numbers = try parts.map { part -> UInt64 in
            guard !part.isEmpty,
                  part.allSatisfy(\.isNumber),
                  !(part.count > 1 && part.first == "0"),
                  let value = UInt64(part) else {
                throw ContractVersionError.malformed(string)
            }
            return value
        }
        self.init(major: numbers[0], minor: numbers[1], patch: numbers[2])
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        try self.init(string: value)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        return lhs.patch < rhs.patch
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static let v1_0_0 = SemanticVersion(major: 1, minor: 0, patch: 0)
}

/// An inclusive SemVer range. A declared range must represent semantics the peer actually implements.
public struct ProtocolRange: Codable, Hashable, Sendable {
    public let minimum: SemanticVersion
    public let maximum: SemanticVersion

    /// Creates an inclusive range, rejecting an inverted range instead of terminating the process.
    public init(minimum: SemanticVersion, maximum: SemanticVersion) throws {
        guard minimum <= maximum else {
            throw ContractVersionError.rangeInverted
        }
        self.minimum = minimum
        self.maximum = maximum
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case minimum
        case maximum
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ProtocolRange")
        try self.init(
            minimum: try container.decode(SemanticVersion.self, forKey: .minimum),
            maximum: try container.decode(SemanticVersion.self, forKey: .maximum)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(minimum, forKey: .minimum)
        try container.encode(maximum, forKey: .maximum)
    }

    public func supports(_ version: SemanticVersion) -> Bool {
        minimum <= version && version <= maximum
    }

    public func intersection(with other: ProtocolRange) -> ProtocolRange? {
        let lower = Swift.max(minimum, other.minimum)
        let upper = Swift.min(maximum, other.maximum)
        guard lower <= upper else { return nil }
        return try? ProtocolRange(minimum: lower, maximum: upper)
    }
}

/// Immutable metadata for a Contract release. Package tags remain authoritative for SPM versioning;
/// this value is negotiated on the wire and used by contract validation.
public struct ContractProfile: Codable, Hashable, Sendable {
    public let packageVersion: SemanticVersion
    public let protocolVersion: SemanticVersion
    public let supportedProtocolRange: ProtocolRange
    public let schemaVersion: SemanticVersion

    public init(
        packageVersion: SemanticVersion,
        protocolVersion: SemanticVersion,
        supportedProtocolRange: ProtocolRange,
        schemaVersion: SemanticVersion
    ) {
        self.packageVersion = packageVersion
        self.protocolVersion = protocolVersion
        self.supportedProtocolRange = supportedProtocolRange
        self.schemaVersion = schemaVersion
    }

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case packageVersion
        case protocolVersion
        case supportedProtocolRange
        case schemaVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try strictContainer(CodingKeys.self, from: decoder, type: "ContractProfile")
        self.init(
            packageVersion: try container.decode(SemanticVersion.self, forKey: .packageVersion),
            protocolVersion: try container.decode(SemanticVersion.self, forKey: .protocolVersion),
            supportedProtocolRange: try container.decode(ProtocolRange.self, forKey: .supportedProtocolRange),
            schemaVersion: try container.decode(SemanticVersion.self, forKey: .schemaVersion)
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(packageVersion, forKey: .packageVersion)
        try container.encode(protocolVersion, forKey: .protocolVersion)
        try container.encode(supportedProtocolRange, forKey: .supportedProtocolRange)
        try container.encode(schemaVersion, forKey: .schemaVersion)
    }
}

public enum ContractProfiles {
    /// The baseline contract implemented by this package. No future compatibility is claimed.
    public static let v1 = ContractProfile(
        packageVersion: .v1_0_0,
        protocolVersion: .v1_0_0,
        supportedProtocolRange: try! ProtocolRange(
            minimum: .v1_0_0,
            maximum: .v1_0_0
        ),
        schemaVersion: .v1_0_0
    )

    public static let current = v1
}

public enum ContractCompatibility {
    /// Returns the highest mutually supported version. Peers must never advertise a version whose
    /// semantics they do not implement; negotiation is not a silent downgrade mechanism.
    public static func negotiatedVersion(
        client: ProtocolRange,
        host: ProtocolRange
    ) -> SemanticVersion? {
        client.intersection(with: host)?.maximum
    }

    public static func isCompatible(client: ProtocolRange, host: ProtocolRange) -> Bool {
        negotiatedVersion(client: client, host: host) != nil
    }
}
