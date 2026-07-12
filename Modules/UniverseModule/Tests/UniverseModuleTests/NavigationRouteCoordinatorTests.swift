import Foundation
import simd
import Testing
@testable import UniverseModule

@MainActor
@Test func navigationRouteCoordinatorSmoothsLiveRefreshGeometry() throws {
    let transferOrbit = try #require(HohmannTransferOrbit.make(destinationName: "Mars",
                                                               planets: testPlanets,
                                                               earthSunDirection: SIMD3<Float>(1, 0, 0)))
    let initialDestination = SIMD3<Float>(1.52, 0, 0)
    let initialRoute = try makeTestNavigationRoute(transferOrbit: transferOrbit,
                                                   destinationPosition: initialDestination)
    let coordinator = NavigationRouteCoordinator(
        routeBuilder: StaticNavigationRouteBuilder(route: initialRoute),
        playback: StaticNavigationRoutePlayback(),
        snapshotPublisher: { _ in }
    )
    let didStart = coordinator.start(destinationName: "Mars",
                                     planets: testPlanets,
                                     snapshot: .navigationRouteCoordinatorTestSnapshot)
    #expect(didStart)

    let updatedDestination = SIMD3<Float>(0, 0, -1.52)
    let targetPoints = RoutePathBuilder.makeNavigationPoints(
        transferOrbit: transferOrbit,
        destinationPosition: updatedDestination,
        destinationArcSampleCount: initialRoute.points.count - transferOrbit.points.count
    )
    let targetEndPoint = try #require(targetPoints.last)
    let initialEndPoint = try #require(initialRoute.points.last)

    coordinator.refresh(using: transferOrbit,
                        destinationPosition: updatedDestination)
    let smoothedRoute = try #require(coordinator.route)
    let smoothedEndPoint = try #require(smoothedRoute.points.last)

    #expect(smoothedRoute.points.count == initialRoute.points.count)
    #expect(simd_distance(smoothedEndPoint, initialEndPoint) > 0.0001)
    #expect(simd_distance(smoothedEndPoint, targetEndPoint) > 0.0001)
    #expect(simd_distance(smoothedEndPoint, targetEndPoint) <
            simd_distance(initialEndPoint, targetEndPoint))

    let oneFrameDistance = simd_distance(smoothedEndPoint, targetEndPoint)
    for _ in 0..<20 {
        coordinator.refresh(using: transferOrbit,
                            destinationPosition: updatedDestination)
    }
    let convergedEndPoint = try #require(coordinator.route?.points.last)

    #expect(simd_distance(convergedEndPoint, targetEndPoint) < oneFrameDistance * 0.2)
}

@MainActor
@Test func navigationRouteCoordinatorSkipsTinyLiveRefreshGeometry() throws {
    let transferOrbit = try #require(HohmannTransferOrbit.make(destinationName: "Mars",
                                                               planets: testPlanets,
                                                               earthSunDirection: SIMD3<Float>(1, 0, 0)))
    let initialDestination = SIMD3<Float>(1.52, 0, 0)
    let initialRoute = try makeTestNavigationRoute(transferOrbit: transferOrbit,
                                                   destinationPosition: initialDestination)
    let coordinator = NavigationRouteCoordinator(
        routeBuilder: StaticNavigationRouteBuilder(route: initialRoute),
        playback: StaticNavigationRoutePlayback(),
        snapshotPublisher: { _ in }
    )
    let didStart = coordinator.start(destinationName: "Mars",
                                     planets: testPlanets,
                                     snapshot: .navigationRouteCoordinatorTestSnapshot)
    #expect(didStart)

    coordinator.refresh(using: transferOrbit,
                        destinationPosition: SIMD3<Float>(1.52, 0, -0.000_01))

    #expect(coordinator.route == initialRoute)
}

@MainActor
@Test func navigationRouteCoordinatorRefreshesArtemisRouteAroundUpdatedMoonPrediction() throws {
    let planets = artemisTestPlanets(earthOrbitSpeed: 0.25,
                                     moonOrbitSpeed: 0.4)
    let playback = StaticNavigationRoutePlayback()
    let coordinator = NavigationRouteCoordinator(
        routeBuilder: RoutePathBuilder(sampleCount: 96),
        playback: playback,
        snapshotPublisher: { _ in }
    )
    let didStart = coordinator.start(originName: "Earth",
                                     waypointName: "Moon",
                                     destinationName: "Earth",
                                     planets: planets,
                                     snapshot: artemisSnapshot(planets: planets,
                                                               simulationTime: 10))
    #expect(didStart)

    playback.setProgress(0.25)
    let refreshedSnapshot = artemisSnapshot(planets: planets,
                                            simulationTime: 20)
    coordinator.refreshArtemisRoute(planets: planets,
                                    snapshot: refreshedSnapshot)
    let route = try #require(coordinator.route)
    let earthPosition = try #require(refreshedSnapshot.worldPosition(ofPlanetNamed: "Earth"))
    let currentMoonPosition = try #require(refreshedSnapshot.worldPosition(ofPlanetNamed: "Moon"))
    let input = RouteBuildInput(
        originName: "Earth",
        waypointName: "Moon",
        destinationName: "Earth",
        planets: planets,
        originPosition: earthPosition,
        waypointPosition: currentMoonPosition,
        originSurfaceRadius: refreshedSnapshot.surfaceRadius(ofPlanetNamed: "Earth") ?? 0,
        waypointSurfaceRadius: refreshedSnapshot.surfaceRadius(ofPlanetNamed: "Moon") ?? 0,
        destinationSurfaceRadius: refreshedSnapshot.surfaceRadius(ofPlanetNamed: "Earth") ?? 0,
        earthSunDirection: earthPosition,
        sunPosition: .zero,
        destinationPosition: earthPosition,
        estimatedDuration: route.estimatedDuration,
        simulationTime: refreshedSnapshot.simulationTime,
        routeProgress: playback.progress
    )
    let predictedMoonPosition = try #require(RoutePathBuilder.predictedArtemisWaypointPosition(input: input))
    let moonSurfaceRadius = refreshedSnapshot.surfaceRadius(ofPlanetNamed: "Moon") ?? 0
    let flybyGeometry = artemisLunarFlybyGeometry(originPosition: earthPosition,
                                                 waypointPosition: currentMoonPosition,
                                                 waypointSurfaceRadius: moonSurfaceRadius)
    let currentMoonMinimumDistance = route.points.map {
        simd_distance($0, currentMoonPosition)
    }.min() ?? .greatestFiniteMagnitude
    let predictedMoonMinimumDistance = route.points.map {
        simd_distance($0, predictedMoonPosition)
    }.min() ?? .greatestFiniteMagnitude

    #expect(currentMoonMinimumDistance < predictedMoonMinimumDistance)
    try expectArtemisLunarFlybyShape(route: route,
                                     geometry: flybyGeometry,
                                     center: currentMoonPosition,
                                     surfaceRadius: moonSurfaceRadius,
                                     sampleCount: 96)
    let routeEnd = try #require(route.points.last)
    let predictedDestination = try #require(RoutePathBuilder.predictedArtemisDestinationPosition(input: input))
    #expect(simd_distance(predictedDestination, earthPosition) > 0.1)
    #expect(simd_distance(routeEnd, earthPosition) <
            (refreshedSnapshot.surfaceRadius(ofPlanetNamed: "Earth") ?? 0)
            * 1.12 * 1.01)
    #expect(simd_distance(routeEnd, earthPosition) <
            simd_distance(routeEnd, predictedDestination))
    #expect(simd_distance(predictedMoonPosition, currentMoonPosition) > 0.05)
}

private func makeTestNavigationRoute(transferOrbit: HohmannTransferOrbit,
                                     destinationPosition: SIMD3<Float>) throws -> NavigationRoute {
    let points = RoutePathBuilder.makeNavigationPoints(transferOrbit: transferOrbit,
                                                       destinationPosition: destinationPosition)
    let cumulativeDistances = RoutePathBuilder.makeCumulativeDistances(points: points)
    let totalDistance = try #require(cumulativeDistances.last)

    return NavigationRoute(originName: "Earth",
                           destinationName: transferOrbit.destinationName,
                           points: points,
                           cumulativeDistances: cumulativeDistances,
                           totalDistance: totalDistance,
                           estimatedDuration: 12)
}

private struct StaticNavigationRouteBuilder: RouteBuilding {
    let route: NavigationRoute

    func makeRoute(input: RouteBuildInput) -> NavigationRoute? {
        route
    }
}

private final class StaticNavigationRoutePlayback: RoutePlayback {
    private(set) var progress: Float = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var isCompleted = false

    func setProgress(_ progress: Float) {
        self.progress = progress
    }

    func start(duration: TimeInterval) {
        progress = 0
        elapsedTime = 0
        isCompleted = false
    }

    func pause() {}

    func resume() {}

    func cancel() {
        progress = 0
        elapsedTime = 0
        isCompleted = false
    }

    func update() {}
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

private func artemisSnapshot(planets: [Planet],
                             simulationTime: Float) -> UniverseSceneSnapshot {
    var worldPositionsByName: [String: SIMD3<Float>] = [:]
    let packets = planets.map { planet in
        let parentWorldPosition = planet.parentName.flatMap {
            worldPositionsByName[$0]
        }
        let orbitTransformMatrix = planet.orbitTransformMatrix(at: simulationTime,
                                                               parentWorldPosition: parentWorldPosition)
        let worldPosition4 = orbitTransformMatrix * SIMD4<Float>(0, 0, 0, 1)
        let worldPosition = SIMD3<Float>(worldPosition4.x,
                                         worldPosition4.y,
                                         worldPosition4.z)
        worldPositionsByName[planet.name] = worldPosition
        return CelestialBodySnapshot(planetName: planet.name,
                                     baseModelMatrix: orbitTransformMatrix,
                                     normalizedScale: 1,
                                     framingRadius: planet.name == "Moon" ? 0.01 : 0.02,
                                     surfaceRadius: planet.name == "Moon" ? 0.01 : 0.02,
                                     worldPosition: worldPosition)
    }

    return UniverseSceneSnapshot(frameID: UInt64(simulationTime),
                                 simulationTime: simulationTime,
                                 planets: packets)
}

private extension UniverseSceneSnapshot {
    static var navigationRouteCoordinatorTestSnapshot: UniverseSceneSnapshot {
        UniverseSceneSnapshot(frameID: 1,
                              simulationTime: 0,
                              planets: [
                                testPacket(name: "Sun",
                                           worldPosition: SIMD3<Float>(0, 0, 0),
                                           framingRadius: 0.2),
                                testPacket(name: "Earth",
                                           worldPosition: SIMD3<Float>(1, 0, 0),
                                           framingRadius: 0.05),
                                testPacket(name: "Mars",
                                           worldPosition: SIMD3<Float>(1.52, 0, 0),
                                           framingRadius: 0.05)
                              ])
    }

    static func testPacket(name: String,
                           worldPosition: SIMD3<Float>,
                           framingRadius: Float) -> CelestialBodySnapshot {
        CelestialBodySnapshot(planetName: name,
                              baseModelMatrix: matrix_identity_float4x4,
                              normalizedScale: 1,
                              framingRadius: framingRadius,
                              surfaceRadius: framingRadius,
                              worldPosition: worldPosition)
    }
}
