import Testing
@testable import CommonTools

@Test func safeArraySubscriptReturnsElementForValidIndex() {
    let values = ["Sun", "Earth", "Mars"]

    #expect(values[safe: 0] == "Sun")
    #expect(values[safe: 2] == "Mars")
}

@Test func safeArraySubscriptReturnsNilForInvalidIndex() {
    let values = ["Sun", "Earth", "Mars"]

    #expect(values[safe: -1] == nil)
    #expect(values[safe: 3] == nil)
}
