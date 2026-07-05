import Foundation
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

@Test func routeBuilderCreatesRealLikeArtemisStages() throws {
    let originPosition = SIMD3<Float>(1, 0, 0)
    let waypointPosition = SIMD3<Float>(1.2, 0, 0)
    let originSurfaceRadius: Float = 0.02
    let waypointSurfaceRadius: Float = 0.01
    let input = RouteBuildInput(
        originName: "Earth",
        waypointName: "Moon",
        destinationName: "Earth",
        planets: artemisTestPlanets(moonOrbitSpeed: 0),
        originPosition: originPosition,
        waypointPosition: waypointPosition,
        originSurfaceRadius: originSurfaceRadius,
        waypointSurfaceRadius: waypointSurfaceRadius,
        destinationSurfaceRadius: originSurfaceRadius,
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sunPosition: .zero,
        destinationPosition: originPosition,
        estimatedDuration: 16
    )
    let route = try #require(RoutePathBuilder(sampleCount: 96).makeRoute(input: input))
    let firstPoint = try #require(route.points.first)
    let lastPoint = try #require(route.points.last)
    let predictedMoon = try #require(RoutePathBuilder.predictedArtemisWaypointPosition(input: input))
    let direction = normalize(predictedMoon - originPosition)
    let sideDirection = artemisSideDirection(originPosition: originPosition,
                                             waypointPosition: predictedMoon)
    let lunarFlybyRadius = max(
        waypointSurfaceRadius * ArtemisRouteProfile.lunarFlybyRadiusScale,
        simd_distance(originPosition, predictedMoon) * ArtemisRouteProfile.lunarFlybyDistanceScale,
        0.01
    )
    let lunarApproach = predictedMoon
        - direction * lunarFlybyRadius * ArtemisFlybyTestProfile.approachMajorScale
        - sideDirection * lunarFlybyRadius * ArtemisFlybyTestProfile.approachLateralScale
        + SIMD3<Float>(0, 1, 0) * lunarFlybyRadius * 0.04
    let lunarHook = predictedMoon
        + direction * lunarFlybyRadius * ArtemisFlybyTestProfile.hookMajorScale
        + sideDirection * lunarFlybyRadius * ArtemisFlybyTestProfile.hookLateralScale
        + SIMD3<Float>(0, 1, 0) * lunarFlybyRadius * ArtemisFlybyTestProfile.tiltScale
    let lunarDeparture = predictedMoon
        - direction * lunarFlybyRadius * ArtemisFlybyTestProfile.exitMajorScale
        + sideDirection * lunarFlybyRadius * ArtemisFlybyTestProfile.exitLateralScale
        + SIMD3<Float>(0, 1, 0) * lunarFlybyRadius * 0.08

    #expect(route.originName == "Earth")
    #expect(route.waypointName == "Moon")
    #expect(route.destinationName == "Earth")
    #expect(route.estimatedDuration == 16)
    expectVector(firstPoint,
                 equals: originPosition + direction * originSurfaceRadius * 1.12)
    expectVector(lastPoint,
                 equals: originPosition + direction * originSurfaceRadius * 1.12)
    #expect(route.points.contains { simd_distance($0, lunarApproach) < 0.0001 })
    #expect(route.points.contains { simd_distance($0, lunarHook) < 0.0001 })
    #expect(route.points.contains { simd_distance($0, lunarDeparture) < 0.0001 })
    let departureIndex = try #require(route.points.firstIndex {
        simd_distance($0, lunarDeparture) < 0.0001
    })
    let postDepartureIndex = try #require(route.points.indices.contains(departureIndex + 1)
                                          ? departureIndex + 1
                                          : nil)
    #expect(simd_dot(route.points[postDepartureIndex] - route.points[departureIndex],
                     direction) < 0)
    let lunarLateralOffsets = route.points
        .filter { simd_distance($0, predictedMoon) < lunarFlybyRadius * 3 }
        .map { simd_dot($0 - predictedMoon, sideDirection) }
    #expect((lunarLateralOffsets.max() ?? 0) >
            lunarFlybyRadius * ArtemisFlybyTestProfile.exitLateralScale)
    #expect((lunarLateralOffsets.min() ?? 0) <
            -lunarFlybyRadius * ArtemisFlybyTestProfile.approachLateralScale * 0.5)
    #expect(route.totalDistance > simd_distance(originPosition, waypointPosition) * 2)
    #expect((route.points.map { abs($0.z) }.max() ?? 0) >
            simd_distance(originPosition, waypointPosition) * 0.08)
    #expect((route.points.map { abs($0.y) }.max() ?? 0) >
            lunarFlybyRadius * 0.1)

    for index in route.cumulativeDistances.indices.dropFirst() {
        #expect(route.cumulativeDistances[index] >= route.cumulativeDistances[index - 1])
    }
}

@Test func routeBuilderTargetsPredictedMoonPosition() throws {
    let originPosition = SIMD3<Float>(1, 0, 0)
    let simulationTime: Float = 10
    let planets = artemisTestPlanets(moonOrbitSpeed: 0.4)
    let currentMoonPosition = worldPosition(of: "Moon",
                                            planets: planets,
                                            simulationTime: simulationTime)
    let originSurfaceRadius: Float = 0.02
    let waypointSurfaceRadius: Float = 0.01
    let input = RouteBuildInput(
        originName: "Earth",
        waypointName: "Moon",
        destinationName: "Earth",
        planets: planets,
        originPosition: originPosition,
        waypointPosition: currentMoonPosition,
        originSurfaceRadius: originSurfaceRadius,
        waypointSurfaceRadius: waypointSurfaceRadius,
        destinationSurfaceRadius: originSurfaceRadius,
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sunPosition: .zero,
        destinationPosition: originPosition,
        estimatedDuration: 16,
        simulationTime: simulationTime
    )
    let predictedMoonPosition = try #require(RoutePathBuilder.predictedArtemisWaypointPosition(input: input))
    let route = try #require(RoutePathBuilder(sampleCount: 96).makeRoute(input: input))
    let predictedMoonMinimumDistance = route.points.map {
        simd_distance($0, predictedMoonPosition)
    }.min() ?? .greatestFiniteMagnitude
    let currentMoonMinimumDistance = route.points.map {
        simd_distance($0, currentMoonPosition)
    }.min() ?? .greatestFiniteMagnitude

    #expect(simd_distance(predictedMoonPosition, currentMoonPosition) > 0.1)
    #expect(predictedMoonMinimumDistance < currentMoonMinimumDistance)
    #expect(abs(route.overviewPaddingRadius - originSurfaceRadius * 1.2) < 0.0001)
}

@Test func routeBuilderSmoothsArtemisSegmentJoins() throws {
    let originPosition = SIMD3<Float>(1, 0, 0)
    let waypointPosition = SIMD3<Float>(1.2, 0, 0)
    let route = try #require(RoutePathBuilder(sampleCount: 192).makeRoute(input: RouteBuildInput(
        originName: "Earth",
        waypointName: "Moon",
        destinationName: "Earth",
        planets: artemisTestPlanets(moonOrbitSpeed: 0),
        originPosition: originPosition,
        waypointPosition: waypointPosition,
        originSurfaceRadius: 0.02,
        waypointSurfaceRadius: 0.01,
        destinationSurfaceRadius: 0.02,
        earthSunDirection: SIMD3<Float>(1, 0, 0),
        sunPosition: .zero,
        destinationPosition: originPosition,
        estimatedDuration: 16
    )))

    #expect(maximumTurnAngle(points: route.points) < 0.9)
}

@Test func routeBuilderReturnsArtemisToCurrentRenderedEarthWhenEarthMoves() throws {
    let simulationTime: Float = 10
    let planets = artemisTestPlanets(earthOrbitSpeed: 0.25,
                                     moonOrbitSpeed: 0.4)
    let currentEarthPosition = worldPosition(of: "Earth",
                                             planets: planets,
                                             simulationTime: simulationTime)
    let currentMoonPosition = worldPosition(of: "Moon",
                                            planets: planets,
                                            simulationTime: simulationTime)
    let originSurfaceRadius: Float = 0.02
    let input = RouteBuildInput(
        originName: "Earth",
        waypointName: "Moon",
        destinationName: "Earth",
        planets: planets,
        originPosition: currentEarthPosition,
        waypointPosition: currentMoonPosition,
        originSurfaceRadius: originSurfaceRadius,
        waypointSurfaceRadius: 0.01,
        destinationSurfaceRadius: originSurfaceRadius,
        earthSunDirection: currentEarthPosition,
        sunPosition: .zero,
        destinationPosition: currentEarthPosition,
        estimatedDuration: 16,
        simulationTime: simulationTime
    )
    let route = try #require(RoutePathBuilder(sampleCount: 96).makeRoute(input: input))
    let lastPoint = try #require(route.points.last)
    let predictedDestination = try #require(RoutePathBuilder.predictedArtemisDestinationPosition(input: input))

    #expect(simd_distance(predictedDestination, currentEarthPosition) > 0.1)
    #expect(simd_distance(lastPoint, currentEarthPosition) <
            originSurfaceRadius * 1.12 * 1.01)
    #expect(simd_distance(lastPoint, currentEarthPosition) <
            simd_distance(lastPoint, predictedDestination))
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

private func maximumTurnAngle(points: [SIMD3<Float>]) -> Float {
    guard points.count >= 3 else { return 0 }

    var maximumAngle: Float = 0
    for index in 1..<(points.count - 1) {
        let previous = points[index] - points[index - 1]
        let next = points[index + 1] - points[index]
        guard simd_length_squared(previous) > 0.000_001,
              simd_length_squared(next) > 0.000_001 else {
            continue
        }

        let dotValue = simd_clamp(simd_dot(normalize(previous), normalize(next)), -1, 1)
        maximumAngle = max(maximumAngle, acos(dotValue))
    }

    return maximumAngle
}

private enum ArtemisFlybyTestProfile {
    static let approachMajorScale: Float = 1.08
    static let approachLateralScale: Float = 0.45
    static let hookMajorScale: Float = 0.55
    static let hookLateralScale: Float = 0.95
    static let exitMajorScale: Float = 0.78
    static let exitLateralScale: Float = 0.55
    static let tiltScale: Float = 0.16
}

private func artemisSideDirection(originPosition: SIMD3<Float>,
                                  waypointPosition: SIMD3<Float>) -> SIMD3<Float> {
    let majorVector = waypointPosition - originPosition
    let horizontalMajor = SIMD3<Float>(majorVector.x, 0, majorVector.z)
    guard simd_length_squared(horizontalMajor) > 0.000_001 else {
        return SIMD3<Float>(0, 1, 0)
    }

    return normalize(SIMD3<Float>(-horizontalMajor.z, 0, horizontalMajor.x))
}

private func artemisTestPlanets(earthOrbitSpeed: Float = 0,
                                moonOrbitSpeed: Float) -> [Planet] {
    [
        Planet(name: "Sun",
               meshName: "Sun",
               parentName: nil,
               radius: 1,
               distance: 0,
               orbitSpeed: 0,
               rotationSpeedKmSec: 0),
        Planet(name: "Earth",
               meshName: "Earth",
               parentName: nil,
               radius: 1,
               distance: 1,
               orbitSpeed: earthOrbitSpeed,
               rotationSpeedKmSec: 0),
        Planet(name: "Moon",
               meshName: "Moon",
               parentName: "Earth",
               radius: 1,
               distance: 0.2,
               orbitSpeed: moonOrbitSpeed,
               rotationSpeedKmSec: 0)
    ]
}

private func worldPosition(of planetName: String,
                           planets: [Planet],
                           simulationTime: Float) -> SIMD3<Float> {
    var worldPositionsByName: [String: SIMD3<Float>] = [:]

    for planet in planets {
        let parentWorldPosition = planet.parentName.flatMap {
            worldPositionsByName[$0]
        }
        let orbitTransformMatrix = planet.orbitTransformMatrix(at: simulationTime,
                                                               parentWorldPosition: parentWorldPosition)
        let worldPosition4 = orbitTransformMatrix * SIMD4<Float>(0, 0, 0, 1)
        worldPositionsByName[planet.name] = SIMD3<Float>(worldPosition4.x,
                                                         worldPosition4.y,
                                                         worldPosition4.z)
    }

    return worldPositionsByName[planetName] ?? .zero
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
