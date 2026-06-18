import simd
import Testing
@testable import UniverseModule

@Test func generatedStarsAreDeterministicForSeed() {
    let configuration = StarFieldConfiguration(
        density: 0.02,
        innerRadius: 10,
        outerRadius: 20,
        seed: 42,
        colorPalette: [
            SIMD3<Float>(1, 1, 1),
            SIMD3<Float>(0.7, 0.8, 1.0)
        ],
        minimumBrightness: 0.5,
        maximumBrightness: 1.5,
        minimumPointSize: 1,
        maximumPointSize: 2
    )

    let lhs = StarFieldGenerator.makeStars(configuration: configuration)
    let rhs = StarFieldGenerator.makeStars(configuration: configuration)

    #expect(lhs.count == rhs.count)
    for index in lhs.indices {
        #expect(lhs[index].positionAndSize.x == rhs[index].positionAndSize.x)
        #expect(lhs[index].positionAndSize.y == rhs[index].positionAndSize.y)
        #expect(lhs[index].positionAndSize.z == rhs[index].positionAndSize.z)
        #expect(lhs[index].positionAndSize.w == rhs[index].positionAndSize.w)
        #expect(lhs[index].colorAndBrightness.x == rhs[index].colorAndBrightness.x)
        #expect(lhs[index].colorAndBrightness.y == rhs[index].colorAndBrightness.y)
        #expect(lhs[index].colorAndBrightness.z == rhs[index].colorAndBrightness.z)
        #expect(lhs[index].colorAndBrightness.w == rhs[index].colorAndBrightness.w)
    }
}

@Test func generatedPositionsStayWithinConfiguredRadii() {
    let configuration = StarFieldConfiguration(
        density: 0.05,
        innerRadius: 25,
        outerRadius: 50,
        seed: 7
    )

    let stars = StarFieldGenerator.makeStars(configuration: configuration)

    #expect(!stars.isEmpty)
    for star in stars {
        let radius = simd_length(star.position)
        #expect(radius >= configuration.innerRadius)
        #expect(radius <= configuration.outerRadius)
    }
}

@Test func generatedColorsComeFromPalette() {
    let palette = [
        SIMD3<Float>(1, 0, 0),
        SIMD3<Float>(0, 1, 0),
        SIMD3<Float>(0, 0, 1)
    ]
    let configuration = StarFieldConfiguration(
        density: 0.04,
        seed: 11,
        colorPalette: palette
    )

    let stars = StarFieldGenerator.makeStars(configuration: configuration)

    #expect(!stars.isEmpty)
    for star in stars {
        #expect(palette.contains { paletteColor in
            paletteColor.x == star.color.x &&
            paletteColor.y == star.color.y &&
            paletteColor.z == star.color.z
        })
    }
}
