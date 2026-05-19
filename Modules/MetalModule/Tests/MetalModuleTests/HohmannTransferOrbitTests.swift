import simd
import Testing
@testable import MetalModule

@Test func hohmannSemiMajorAxisUsesMeanOrbitRadius() {
    let transfer = HohmannTransferOrbit.make(destinationName: "Mars",
                                             planets: testPlanets,
                                             earthSunDirection: SIMD3<Float>(1, 0, 0),
                                             sampleCount: 16)

    #expect(abs((transfer?.semiMajorAxis ?? 0) - 1.26) < 0.0001)
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
