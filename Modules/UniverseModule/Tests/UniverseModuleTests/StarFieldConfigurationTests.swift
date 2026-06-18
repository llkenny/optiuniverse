import Foundation
import Testing
@testable import UniverseModule

@Test func densityMapsToExpectedCountAndClamps() {
    #expect(StarFieldConfiguration.defaultBaseStarCount == 3_200)
    #expect(StarFieldConfiguration().starCount == 4_000)
    #expect(StarFieldConfiguration(density: 1.0).starCount == 3_200)
    #expect(StarFieldConfiguration(density: 0.5).starCount == 1_600)
    #expect(StarFieldConfiguration(density: 10.0).starCount == 12_000)
    #expect(StarFieldConfiguration(density: -1.0).starCount == 0)
    #expect(StarFieldConfiguration(density: .nan).starCount == 0)
}

@Test func defaultStarFieldUsesRestrainedBrightnessAndPointSizeRanges() {
    let configuration = StarFieldConfiguration()

    #expect(configuration.minimumBrightness == 0.28)
    #expect(configuration.maximumBrightness == 1.85)
    #expect(configuration.minimumPointSize == 0.72)
    #expect(configuration.maximumPointSize == 2.05)
}

@Test func starTwinkleConfigurationStaysSubtleAndShaderConstantsStayInSync() throws {
    #expect(StarTwinkle.angularSpeed == 0.42)
    #expect(abs(StarTwinkle.minimumFactor - 0.94) < 0.0001)
    #expect(StarTwinkle.maximumFactor == 1.0)

    let shaderURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/UniverseModule/Shaders/Shaders.metal")
    let shaderSource = try String(contentsOf: shaderURL, encoding: .utf8)

    #expect(shaderSource.contains("0.97 + 0.03"))
    #expect(shaderSource.contains("uniforms.time * 0.42"))
}
