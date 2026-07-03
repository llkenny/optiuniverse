import simd
import Testing
@testable import UniverseModule

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
    let destinationPosition = SIMD3<Float>(0, 0, 1.52)
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
    #expect(route.points.allSatisfy { abs($0.y) < 0.0001 })
}

@Test func routeBuilderConnectsMercuryWithoutReversingArrivalTangent() throws {
    try expectDestinationConnectorContinuesArrivalTangent(destinationName: "Mercury",
                                                         destinationOrbitRadius: 0.38)
}

@Test func routeBuilderConnectsVenusWithoutReversingArrivalTangent() throws {
    try expectDestinationConnectorContinuesArrivalTangent(destinationName: "Venus",
                                                         destinationOrbitRadius: 0.72)
}

@Test func routeBuilderLeavesTransferArcWhenDestinationHasNoOrbitPlaneDirection() throws {
    let route = try #require(RoutePathBuilder(sampleCount: 24).makeRoute(input: RouteBuildInput(
        destinationName: "Mars",
        planets: testPlanets,
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sunPosition: .zero,
        destinationPosition: SIMD3<Float>(0, 1.52, 0),
        estimatedDuration: 12
    )))

    #expect(route.points.count == 24)
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

private func expectDestinationConnectorContinuesArrivalTangent(destinationName: String,
                                                               destinationOrbitRadius: Float) throws {
    let transferPointCount = 24
    let route = try #require(RoutePathBuilder(sampleCount: transferPointCount).makeRoute(input: RouteBuildInput(
        destinationName: destinationName,
        planets: testPlanets,
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sunPosition: .zero,
        destinationPosition: SIMD3<Float>(0, 0, destinationOrbitRadius),
        estimatedDuration: 12
    )))

    #expect(route.points.count > transferPointCount)

    let finalTransferSegment = normalize(route.points[transferPointCount - 1] -
                                         route.points[transferPointCount - 2])
    let firstConnectorSegment = normalize(route.points[transferPointCount] -
                                          route.points[transferPointCount - 1])

    #expect(simd_dot(finalTransferSegment, firstConnectorSegment) > 0)
    #expect(simd_distance(route.points.last ?? .zero,
                          SIMD3<Float>(0, 0, destinationOrbitRadius)) < 0.0001)
}
