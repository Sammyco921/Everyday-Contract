import EverydayContract
import Foundation

enum FixtureSupportError: Error {
    case missing(String)
}

func fixtureData(_ name: String) throws -> Data {
    guard let url = Bundle.module.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "Fixtures"
    ) else {
        throw FixtureSupportError.missing(name)
    }
    return try Data(contentsOf: url)
}

func fixtureMessage(_ name: String) throws -> ContractMessage {
    try JSONContractCoder.decode(fixtureData(name))
}

func jsonObjectsEqual(_ lhs: Data, _ rhs: Data) throws -> Bool {
    let left = try JSONSerialization.jsonObject(with: lhs, options: []) as? NSDictionary
    let right = try JSONSerialization.jsonObject(with: rhs, options: []) as? NSDictionary
    return left == right
}
