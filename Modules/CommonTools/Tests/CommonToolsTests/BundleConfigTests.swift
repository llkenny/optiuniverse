import Foundation
import Testing
@testable import CommonTools

private struct TestConfig: Decodable, Equatable {
    let name: String
}

@Test func missingBundleConfigReturnsEmptyArray() {
    let configs: [TestConfig] = Bundle.main.loadConfig(filename: "MissingVersionOneConfig")

    #expect(configs.isEmpty)
}
