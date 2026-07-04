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

@Test func routeBuilderCreatesContinuousEarthMoonEarthEllipse() throws {
    let originPosition = SIMD3<Float>(1, 0, 0)
    let waypointPosition = SIMD3<Float>(1.2, 0, 0)
    let route = try #require(RoutePathBuilder(sampleCount: 24).makeRoute(input: RouteBuildInput(
        originName: "Earth",
        waypointName: "Moon",
        destinationName: "Earth",
        planets: testPlanets,
        originPosition: originPosition,
        waypointPosition: waypointPosition,
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sunPosition: .zero,
        destinationPosition: originPosition,
        estimatedDuration: 16
    )))
    let firstPoint = try #require(route.points.first)
    let midpoint = try #require(route.point(at: 0.5))
    let lastPoint = try #require(route.points.last)

    #expect(route.originName == "Earth")
    #expect(route.waypointName == "Moon")
    #expect(route.destinationName == "Earth")
    #expect(route.estimatedDuration == 16)
    #expect(simd_distance(firstPoint, originPosition) < 0.0001)
    #expect(simd_distance(midpoint, waypointPosition) < 0.0001)
    #expect(simd_distance(lastPoint, originPosition) < 0.0001)
    #expect(route.totalDistance > simd_distance(originPosition, waypointPosition) * 2)
    #expect((route.points.map { abs($0.z) }.max() ?? 0) >
            simd_distance(originPosition, waypointPosition) * 0.1)

    for index in route.cumulativeDistances.indices.dropFirst() {
        #expect(route.cumulativeDistances[index] >= route.cumulativeDistances[index - 1])
    }
}

@Test func routeBuilderAnchorsEarthMoonEarthRouteNearBodySurfaces() throws {
    let originPosition = SIMD3<Float>(1, 0, 0)
    let waypointPosition = SIMD3<Float>(1.2, 0, 0)
    let originSurfaceRadius: Float = 0.02
    let waypointSurfaceRadius: Float = 0.01
    let route = try #require(RoutePathBuilder(sampleCount: 24).makeRoute(input: RouteBuildInput(
        originName: "Earth",
        waypointName: "Moon",
        destinationName: "Earth",
        planets: testPlanets,
        originPosition: originPosition,
        waypointPosition: waypointPosition,
        originSurfaceRadius: originSurfaceRadius,
        waypointSurfaceRadius: waypointSurfaceRadius,
        destinationSurfaceRadius: originSurfaceRadius,
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sunPosition: .zero,
        destinationPosition: originPosition,
        estimatedDuration: 16
    )))
    let direction = normalize(waypointPosition - originPosition)
    let firstPoint = try #require(route.points.first)
    let flybyPoint = route.points[route.points.count / 2]
    let lastPoint = try #require(route.points.last)

    expectVector(firstPoint,
                 equals: originPosition + direction * originSurfaceRadius * 1.12)
    expectVector(flybyPoint,
                 equals: waypointPosition - direction * waypointSurfaceRadius * 1.12)
    expectVector(lastPoint,
                 equals: originPosition - direction * originSurfaceRadius * 1.12)
    #expect(abs(route.overviewPaddingRadius - originSurfaceRadius * 1.2) < 0.0001)

    for index in route.cumulativeDistances.indices.dropFirst() {
        #expect(route.cumulativeDistances[index] >= route.cumulativeDistances[index - 1])
    }
}

@Test func routeBuilderRejectsUnsupportedNonEarthOriginRoutes() {
    let route = RoutePathBuilder(sampleCount: 24).makeRoute(input: RouteBuildInput(
        originName: "Moon",
        waypointName: "Earth",
        destinationName: "Mars",
        planets: testPlanets,
        originPosition: SIMD3<Float>(1.2, 0, 0),
        waypointPosition: SIMD3<Float>(1, 0, 0),
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sunPosition: .zero,
        destinationPosition: SIMD3<Float>(1.52, 0, 0),
        estimatedDuration: 12
    ))

    #expect(route == nil)
}

private func expectVector(_ lhs: SIMD3<Float>,
                          equals rhs: SIMD3<Float>,
                          tolerance: Float = 0.0001) {
    #expect(simd_distance(lhs, rhs) < tolerance)
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
