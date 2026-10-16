import Foundation
import simd
import Testing
@testable import UniverseModule

@MainActor
@Test(arguments: [Float(0.25), 0.9, 0.99, 1])
func navigationRouteCoordinatorRefreshesArtemisRouteAroundUpdatedMoonPrediction(progress: Float) throws {
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

    let routeID = coordinator.route?.id
    playback.setProgress(progress)
    let refreshedSnapshot = artemisSnapshot(planets: planets,
                                            simulationTime: 20)
    coordinator.refreshRoute(planets: planets,
                             snapshot: refreshedSnapshot)
    let route = try #require(coordinator.route)
    #expect(route.id == routeID)
    #expect(route.estimatedDuration == 16)
    let earthPosition = try #require(refreshedSnapshot.worldPosition(ofPlanetNamed: "Earth"))
    let currentMoonPosition = try #require(refreshedSnapshot.worldPosition(ofPlanetNamed: "Moon"))
    let input = artemisRefreshInput(planets: planets, snapshot: refreshedSnapshot,
                                    duration: route.estimatedDuration, progress: playback.progress)
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

    if progress < ArtemisRouteProfile.lunarEncounterProgress {
        #expect(currentMoonMinimumDistance < predictedMoonMinimumDistance)
        #expect(simd_distance(predictedMoonPosition, currentMoonPosition) > 0.05)
    }
    try expectArtemisLunarFlybyShape(route: route,
                                     geometry: flybyGeometry,
                                     center: currentMoonPosition,
                                     surfaceRadius: moonSurfaceRadius,
                                     sampleCount: 96)
    try expectArtemisReturn(route: route, input: input, snapshot: refreshedSnapshot, progress: progress)
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
                             simulationTime: Double) -> UniverseSceneSnapshot {
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

private func artemisRefreshInput(planets: [Planet], snapshot: UniverseSceneSnapshot,
                                 duration: TimeInterval, progress: Float) -> RouteBuildInput {
    let earthPosition = snapshot.worldPosition(ofPlanetNamed: "Earth")
    let moonPosition = snapshot.worldPosition(ofPlanetNamed: "Moon")
    return RouteBuildInput(
        originName: "Earth",
        waypointName: "Moon",
        destinationName: "Earth",
        planets: planets,
        originPosition: earthPosition,
        waypointPosition: moonPosition,
        originSurfaceRadius: snapshot.surfaceRadius(ofPlanetNamed: "Earth") ?? 0,
        waypointSurfaceRadius: snapshot.surfaceRadius(ofPlanetNamed: "Moon") ?? 0,
        destinationSurfaceRadius: snapshot.surfaceRadius(ofPlanetNamed: "Earth") ?? 0,
        earthSunDirection: earthPosition ?? .zero,
        sunPosition: .zero,
        destinationPosition: earthPosition,
        estimatedDuration: duration,
        simulationTime: snapshot.simulationTime,
        routeProgress: progress
    )
}

private func expectArtemisReturn(route: NavigationRoute, input: RouteBuildInput,
                                 snapshot: UniverseSceneSnapshot, progress: Float) throws {
    let earthPosition = try #require(snapshot.worldPosition(ofPlanetNamed: "Earth"))
    let routeEnd = try #require(route.points.last)
    let predictedDestination = try #require(RoutePathBuilder.predictedArtemisDestinationPosition(input: input))
    #expect(abs(simd_distance(routeEnd, earthPosition)
                - (snapshot.surfaceRadius(ofPlanetNamed: "Earth") ?? 0)) < 0.000_001)
    if progress < 1 {
        #expect(simd_distance(routeEnd, earthPosition) < simd_distance(routeEnd, predictedDestination))
    }
    let marker = try #require(route.point(at: progress))
    let earthRadius = try #require(snapshot.surfaceRadius(ofPlanetNamed: "Earth"))
    #expect(simd_distance(marker, earthPosition) >= earthRadius - 0.000_001)
}
