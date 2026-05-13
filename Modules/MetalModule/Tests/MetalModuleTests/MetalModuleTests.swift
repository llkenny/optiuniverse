import simd
import Testing
import Foundation
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

@Test func routeBuilderCreatesMonotonicCumulativeDistances() throws {
    let route = try #require(RoutePathBuilder(sampleCount: 24).makeRoute(input: RouteBuildInput(
        destinationName: "Mars",
        planets: testPlanets,
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sunPosition: .zero,
        destinationPosition: nil,
        estimatedDuration: 12
    )))

    #expect(route.points.count == route.cumulativeDistances.count)
    #expect(route.totalDistance > 0)
    #expect(abs((route.cumulativeDistances.last ?? 0) - route.totalDistance) < 0.0001)

    for index in route.cumulativeDistances.indices.dropFirst() {
        #expect(route.cumulativeDistances[index] >= route.cumulativeDistances[index - 1])
    }
}

@Test func routeBuilderExtendsTransferToDestinationOrbitPosition() throws {
    let destinationPosition = SIMD3<Float>(0, -1.52, 0)
    let route = try #require(RoutePathBuilder(sampleCount: 24).makeRoute(input: RouteBuildInput(
        destinationName: "Mars",
        planets: testPlanets,
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sunPosition: .zero,
        destinationPosition: destinationPosition,
        estimatedDuration: 12
    )))

    let finalPoint = try #require(route.points.last)

    #expect(simd_distance(finalPoint, destinationPosition) < 0.0001)
    #expect(route.points.count > 24)
}

@Test func routeProgressMapsToArcLengthPosition() throws {
    let route = NavigationRoute(originName: "Earth",
                                destinationName: "Mars",
                                points: [
                                    SIMD3<Float>(0, 0, 0),
                                    SIMD3<Float>(10, 0, 0),
                                    SIMD3<Float>(10, 10, 0)
                                ],
                                cumulativeDistances: [0, 10, 20],
                                totalDistance: 20,
                                estimatedDuration: 12)

    #expect(route.point(at: 0) == SIMD3<Float>(0, 0, 0))
    #expect(route.point(at: 1) == SIMD3<Float>(10, 10, 0))

    let midpoint = try #require(route.point(at: 0.75))
    #expect(simd_distance(midpoint, SIMD3<Float>(10, 5, 0)) < 0.0001)
}

@Test func routePathReplacementPreservesIdentityAndDuration() throws {
    let route = NavigationRoute(originName: "Earth",
                                destinationName: "Mars",
                                points: [
                                    SIMD3<Float>(0, 0, 0),
                                    SIMD3<Float>(1, 0, 0)
                                ],
                                cumulativeDistances: [0, 1],
                                totalDistance: 1,
                                estimatedDuration: 12)
    let updated = route.replacingPath(points: [
        SIMD3<Float>(2, 0, 0),
        SIMD3<Float>(2, 4, 0)
    ], cumulativeDistances: [0, 4], totalDistance: 4)

    #expect(updated.id == route.id)
    #expect(updated.estimatedDuration == route.estimatedDuration)
    #expect(updated.point(at: 1) == SIMD3<Float>(2, 4, 0))
}

@Test func routeBuilderRejectsUnsupportedDestinations() {
    let builder = RoutePathBuilder()

    #expect(builder.makeRoute(input: RouteBuildInput(
        destinationName: "Sun",
        planets: testPlanets,
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sunPosition: .zero,
        destinationPosition: nil,
        estimatedDuration: 12
    )) == nil)
    #expect(builder.makeRoute(input: RouteBuildInput(
        destinationName: "Moon",
        planets: testPlanets,
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sunPosition: .zero,
        destinationPosition: nil,
        estimatedDuration: 12
    )) == nil)
    #expect(builder.makeRoute(input: RouteBuildInput(
        destinationName: "Earth",
        planets: testPlanets,
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sunPosition: .zero,
        destinationPosition: nil,
        estimatedDuration: 12
    )) == nil)
}

@Test func playbackPauseResumeDoesNotJumpProgress() {
    let clock = ManualClock()
    let playback = RoutePlaybackController(clock: clock.time)

    playback.start(duration: 10)
    clock.now = 3
    #expect(abs(playback.progress - 0.3) < 0.0001)

    playback.pause()
    clock.now = 8
    #expect(abs(playback.progress - 0.3) < 0.0001)

    playback.resume()
    clock.now = 9
    #expect(abs(playback.progress - 0.4) < 0.0001)
}

@Test func playbackCompletesAndCancels() {
    let clock = ManualClock()
    let playback = RoutePlaybackController(clock: clock.time)

    playback.start(duration: 5)
    clock.now = 5
    playback.update()

    #expect(playback.isCompleted)
    #expect(playback.progress == 1)

    playback.cancel()
    #expect(!playback.isCompleted)
    #expect(playback.progress == 0)
}

private final class ManualClock {
    var now: TimeInterval = 0

    func time() -> TimeInterval {
        now
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
