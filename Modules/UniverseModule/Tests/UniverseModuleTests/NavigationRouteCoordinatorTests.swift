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
