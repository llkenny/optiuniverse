import Foundation
import simd
import Testing
@testable import UniverseModule

@Test func lunarCameraKeepsYawBranchAcrossRefreshedRoutes() throws {
    for progress in [Float(0.50), 0.68] {
        for direction in [Float(-1), 1] {
            let mode = MissionCameraMode()
            let route = makeLunarSeamRoute(angle: .pi - direction * 0.001)
            let refreshed = makeLunarSeamRoute(angle: .pi + direction * 0.001)
            // MissionRouteHandler preserves the route ID when replacing its geometry.
            let refreshedRoute = route.replacingPath(
                points: refreshed.points,
                cumulativeDistances: refreshed.cumulativeDistances,
                totalDistance: refreshed.totalDistance
            )
            let before = try lunarSeamOrientation(mode: mode, route: route, progress: progress)
            let after = try lunarSeamOrientation(mode: mode, route: refreshedRoute, progress: progress)
            #expect(abs(simd_dot(before.vector, after.vector)) > 0.9999)

            // Paused playback must keep the same branch on repeated snapshots.
            let repeated = try lunarSeamOrientation(mode: mode, route: refreshedRoute, progress: progress)
            #expect(abs(simd_dot(after.vector, repeated.vector)) > 0.9999)

            // A new mission must not inherit the previous mission's unwrapped heading.
            let restarted = try lunarSeamOrientation(mode: mode, route: refreshed, progress: progress)
            let fresh = try lunarSeamOrientation(mode: MissionCameraMode(), route: refreshed, progress: progress)
            #expect(abs(simd_dot(restarted.vector, fresh.vector)) > 0.9999)
        }
    }
}

private func makeLunarSeamRoute(angle: Float) -> NavigationRoute {
    let direction = SIMD3<Float>(sin(angle), 0, cos(angle))
    let points = [direction, direction * 2]
    return NavigationRoute(originName: "Earth", waypointName: "Moon", destinationName: "Earth",
                           points: points, cumulativeDistances: [0, 1], totalDistance: 1,
                           estimatedDuration: 16)
}

private func lunarSeamOrientation(mode: MissionCameraMode,
                                  route: NavigationRoute,
                                  progress: Float) throws -> simd_quatf {
    let snapshot = UniverseSceneSnapshot(
        frameID: 1, simulationTime: 0,
        planets: [CelestialBodySnapshot(planetName: "Moon", baseModelMatrix: matrix_identity_float4x4,
                                       normalizedScale: 1, framingRadius: 0.05, surfaceRadius: 0.05,
                                       worldPosition: .zero)]
    )
    return try #require(mode.makeCruiseFrame(route: route, progress: progress,
                                            snapshot: snapshot, overviewDistance: 5)?.orientation)
}
