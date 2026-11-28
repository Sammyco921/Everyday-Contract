import EverydayContract
import Foundation
import Testing

@Suite("SemVer and protocol compatibility")
struct VersioningTests {
    @Test("Semantic versions parse strictly and compare in order")
    func semanticVersions() throws {
        let oneZero = try SemanticVersion(string: "1.0.0")
        let oneOne = try SemanticVersion(string: "1.1.0")
        let twoZero = try SemanticVersion(string: "2.0.0")

        #expect(oneZero == .v1_0_0)
        #expect(oneZero < oneOne)
        #expect(oneOne < twoZero)
        #expect(try SemanticVersion(string: "10.20.30").description == "10.20.30")

        #expect(throws: ContractVersionError.self) {
            _ = try SemanticVersion(string: "1.2")
        }
        #expect(throws: ContractVersionError.self) {
            _ = try SemanticVersion(string: "1.02.0")
        }
        #expect(throws: ContractVersionError.self) {
            _ = try SemanticVersion(string: "1.0.x")
        }
    }

    @Test("Supported version range is inclusive")
    func supportedRange() throws {
        let range = try ProtocolRange(
            minimum: try SemanticVersion(string: "1.0.0"),
            maximum: try SemanticVersion(string: "1.2.0")
        )
        #expect(range.supports(try SemanticVersion(string: "1.0.0")))
        #expect(range.supports(try SemanticVersion(string: "1.1.4")))
        #expect(range.supports(try SemanticVersion(string: "1.2.0")))
        #expect(!range.supports(try SemanticVersion(string: "2.0.0")))
    }

    @Test("Negotiation selects the highest mutually supported version")
    func negotiation() throws {
        let client = try ProtocolRange(
            minimum: try SemanticVersion(string: "1.1.0"),
            maximum: try SemanticVersion(string: "1.4.0")
        )
        let host = try ProtocolRange(
            minimum: try SemanticVersion(string: "1.0.0"),
            maximum: try SemanticVersion(string: "1.3.0")
        )
        let expected = try SemanticVersion(string: "1.3.0")
        #expect(ContractCompatibility.negotiatedVersion(client: client, host: host) == expected)
        #expect(ContractCompatibility.isCompatible(client: client, host: host))
    }

    @Test("A major-version boundary has no compatible range")
    func incompatibleMajorVersions() throws {
        let client = try ProtocolRange(
            minimum: try SemanticVersion(string: "1.0.0"),
            maximum: try SemanticVersion(string: "1.9.9")
        )
        let host = try ProtocolRange(
            minimum: try SemanticVersion(string: "2.0.0"),
            maximum: try SemanticVersion(string: "2.1.0")
        )
        #expect(ContractCompatibility.negotiatedVersion(client: client, host: host) == nil)
        #expect(!ContractCompatibility.isCompatible(client: client, host: host))
    }

    @Test("Only the numeric triple SemVer subset is accepted")
    func restrictedSemVerGrammar() {
        #expect(throws: ContractVersionError.self) {
            _ = try SemanticVersion(string: "1.0.0-alpha")
        }
        #expect(throws: ContractVersionError.self) {
            _ = try SemanticVersion(string: "1.0.0+build.5")
        }
        #expect(throws: ContractVersionError.self) {
            _ = try SemanticVersion(string: "1.0.0.0")
        }
    }

    @Test("An inverted programmatic protocol range is recoverable")
    func invertedProgrammaticRange() {
        #expect(throws: ContractVersionError.rangeInverted) {
            _ = try ProtocolRange(
                minimum: SemanticVersion(major: 2, minor: 0, patch: 0),
                maximum: SemanticVersion(major: 1, minor: 0, patch: 0)
            )
        }
    }

    @Test("An inverted encoded protocol range reports the typed range error")
    func invertedEncodedRange() {
        let data = Data(#"{"minimum":"2.0.0","maximum":"1.0.0"}"#.utf8)
        #expect(throws: ContractVersionError.rangeInverted) {
            _ = try JSONDecoder().decode(ProtocolRange.self, from: data)
        }
    }

    @Test("Current profile claims only its implemented baseline")
    func currentProfile() {
        #expect(ContractProfiles.current.packageVersion == SemanticVersion(major: 1, minor: 1, patch: 0))
        #expect(ContractProfiles.current.protocolVersion == .v1_0_0)
        #expect(ContractProfiles.current.schemaVersion == .v1_0_0)
        #expect(!ContractProfiles.current.supportedProtocolRange.supports(
            SemanticVersion(major: 1, minor: 1, patch: 0)
        ))
    }
}
