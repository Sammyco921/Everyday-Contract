import Foundation

private func makeContractJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}

private func makeContractJSONDecoder() -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}

/// The supported validated JSON boundary used by Host and Client.
///
/// `decode` enforces the message-size limit, ISO-8601 date decoding, strict field rejection, JSON
/// nesting limits, and semantic rules in `ContractValidator`. Direct `Codable` decoding of the
/// contract types is structural only: it does not enforce size limits or semantic validation, and
/// applications must not treat it as acceptance of a valid Contract message.
public enum JSONContractCoder {
    public static func encode(_ message: ContractMessage) throws -> Data {
        try ContractValidator.validate(message)
        let data = try makeContractJSONEncoder().encode(message)
        guard data.count <= ContractLimits.maximumMessageBytes else {
            throw ContractValidationError.messageTooLarge(
                bytes: data.count,
                maximum: ContractLimits.maximumMessageBytes
            )
        }
        return data
    }

    public static func decode(_ data: Data) throws -> ContractMessage {
        guard data.count <= ContractLimits.maximumMessageBytes else {
            throw ContractValidationError.messageTooLarge(
                bytes: data.count,
                maximum: ContractLimits.maximumMessageBytes
            )
        }
        let decoder = makeContractJSONDecoder()
        decoder.userInfo[contractJSONValueDepthKey] = JSONValueDecodingBudget()
        let message = try decoder.decode(ContractMessage.self, from: data)
        try ContractValidator.validate(message)
        return message
    }

    /// Deterministic bytes for test fixtures and future content hashing. Field order is sorted by
    /// the shared encoder configuration; callers must not reinterpret it as authority.
    public static func canonicalData(for message: ContractMessage) throws -> Data {
        try encode(message)
    }
}
