import simd
import Testing
@testable import MetalModule

private let testPlanets: [Planet] = [
    Planet(name: "Sun",
           meshName: "Sun",
           parentName: nil,
           radius: 1,
           distance: 0,
           orbitSpeed: 0,
           rotationSpeedKmSec: 0),
    Planet(name: "Mercury",
           meshName: "Mercury",
           parentName: nil,
           radius: 1,
           distance: 0.38,
           orbitSpeed: 0,
           rotationSpeedKmSec: 0),
    Planet(name: "Earth",
           meshName: "Earth",
           parentName: nil,
           radius: 1,
           distance: 1,
           orbitSpeed: 0,
           rotationSpeedKmSec: 0),
    Planet(name: "Moon",
           meshName: "Moon",
           parentName: "Earth",
           radius: 1,
           distance: 0.0025,
           orbitSpeed: 0,
           rotationSpeedKmSec: 0),
    Planet(name: "Mars",
           meshName: "Mars",
           parentName: nil,
           radius: 1,
           distance: 1.52,
           orbitSpeed: 0,
           rotationSpeedKmSec: 0)
]

@Test func hohmannSemiMajorAxisUsesMeanOrbitRadius() {
    let transfer = HohmannTransferOrbit.make(destinationName: "Mars",
                                             planets: testPlanets,
                                             earthSunDirection: SIMD3<Float>(1, 0, 0),
                                             sampleCount: 16)

    #expect(abs((transfer?.semiMajorAxis ?? 0) - 1.26) < 0.0001)
    #expect(abs((transfer?.summary.semiMajorAxisAU ?? 0) - 1.26) < 0.0001)
}

@Test func outwardTransferStartsAtEarthAndEndsAtDestinationRadius() throws {
    let transfer = try #require(HohmannTransferOrbit.make(
        destinationName: "Mars",
        planets: testPlanets,
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sampleCount: 16
    ))

    let firstPoint = try #require(transfer.points.first)
    let lastPoint = try #require(transfer.points.last)

    #expect(abs(simd_length(firstPoint) - 1) < 0.0001)
    #expect(abs(simd_length(lastPoint) - 1.52) < 0.0001)
    #expect(lastPoint.x < 0)
}

@Test func inwardTransferStartsAtEarthAndEndsAtInnerDestinationRadius() throws {
    let transfer = try #require(HohmannTransferOrbit.make(
        destinationName: "Mercury",
        planets: testPlanets,
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sampleCount: 16
    ))

    let firstPoint = try #require(transfer.points.first)
    let lastPoint = try #require(transfer.points.last)

    #expect(abs(simd_length(firstPoint) - 1) < 0.0001)
    #expect(abs(simd_length(lastPoint) - 0.38) < 0.0001)
}

@Test func transferArcRotatesFirstPointToEarthDirection() throws {
    let earthDirection = normalize(SIMD3<Float>(0.25, 0.75, 0))
    let transfer = try #require(HohmannTransferOrbit.make(
        destinationName: "Mars",
        planets: testPlanets,
        earthSunDirection: earthDirection,
        sampleCount: 16
    ))

    let firstPoint = normalize(try #require(transfer.points.first))

    #expect(simd_distance(firstPoint, earthDirection) < 0.0001)
}

@Test func unsupportedTransferTargetsReturnNil() {
    #expect(HohmannTransferOrbit.make(destinationName: "Sun",
                                     planets: testPlanets,
                                     earthSunDirection: SIMD3<Float>(1, 0, 0)) == nil)
    #expect(HohmannTransferOrbit.make(destinationName: "Moon",
                                     planets: testPlanets,
                                     earthSunDirection: SIMD3<Float>(1, 0, 0)) == nil)
    #expect(HohmannTransferOrbit.make(destinationName: "Earth",
                                     planets: testPlanets,
                                     earthSunDirection: SIMD3<Float>(1, 0, 0)) == nil)
}

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

@Test func densityMapsToExpectedCountAndClamps() {
    #expect(StarFieldConfiguration(density: 1.0).starCount == 1_600)
    #expect(StarFieldConfiguration(density: 0.5).starCount == 800)
    #expect(StarFieldConfiguration(density: 10.0).starCount == 8_000)
    #expect(StarFieldConfiguration(density: -1.0).starCount == 0)
    #expect(StarFieldConfiguration(density: .nan).starCount == 0)
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
