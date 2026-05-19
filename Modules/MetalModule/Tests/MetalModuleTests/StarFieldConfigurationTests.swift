import Testing
@testable import MetalModule

@Test func densityMapsToExpectedCountAndClamps() {
    #expect(StarFieldConfiguration(density: 1.0).starCount == 1_600)
    #expect(StarFieldConfiguration(density: 0.5).starCount == 800)
    #expect(StarFieldConfiguration(density: 10.0).starCount == 8_000)
    #expect(StarFieldConfiguration(density: -1.0).starCount == 0)
    #expect(StarFieldConfiguration(density: .nan).starCount == 0)
}
