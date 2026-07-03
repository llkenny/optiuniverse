import CoreGraphics
import simd
import Testing
@testable import UniverseModule

@MainActor
@Test func followCameraModeMakesSteadyTargetTransaction() throws {
    let mode = FollowCameraMode()
    let transaction = try #require(mode.makeSteadyFollowTransaction(
        named: "Mars",
        snapshot: .followCameraTestSnapshot
    ))

    #expect(transaction.cameraTarget == SIMD3<Float>(1.52, 0, 0))
}

@MainActor
@Test func followCameraModeReturnsNilForUnresolvedTarget() {
    let mode = FollowCameraMode()

    #expect(mode.makeSteadyFollowTransaction(named: "Venus",
                                             snapshot: .followCameraTestSnapshot) == nil)
    #expect(mode.makeTransitionFrame(named: "Venus",
                                     snapshot: .followCameraTestSnapshot,
                                     currentDistance: 3,
                                     viewportSize: CGSize(width: 390, height: 844)) == nil)
}

@MainActor
@Test func followCameraModeComputesFitDistance() throws {
    let mode = FollowCameraMode()
    let frame = try #require(mode.makeTransitionFrame(
        named: "Mars",
        snapshot: .followCameraTestSnapshot,
        currentDistance: 3,
        viewportSize: CGSize(width: 390, height: 844)
    ))
    let expectedDistance = CameraFit.distanceToFit(radius: 0.05,
                                                   currentDistance: 3,
                                                   viewportSize: CGSize(width: 390, height: 844))

    #expect(frame.target == SIMD3<Float>(1.52, 0, 0))
    #expect(abs(frame.distance - expectedDistance) < 0.000001)
}

@MainActor
@Test func followCameraModeComputesFollowMinimumDistanceAndNearPlane() {
    let mode = FollowCameraMode()
    let minimumDistance = mode.minimumDistance(followingPlanetName: "Mars",
                                               snapshot: .followCameraTestSnapshot,
                                               baseMinimumDistance: 0.001)
    let projection = mode.projectionParameters(
        followingPlanetName: "Mars",
        snapshot: .followCameraTestSnapshot,
        cameraDistance: 0.08,
        baseProjection: CameraProjectionParameters(nearPlane: 0.1,
                                                   farPlane: 10000)
    )

    #expect(abs(minimumDistance - 0.0525) < 0.000001)
    #expect(abs(projection.nearPlane - 0.015) < 0.000001)
    #expect(projection.farPlane == 10000)
}

@MainActor
@Test func followCameraModeKeepsSmallBodiesOutsideMinimumNearPlane() {
    let mode = FollowCameraMode()
    let mercuryRadius: Float = 0.0024395
    let snapshot = UniverseSceneSnapshot(
        frameID: 1,
        simulationTime: 0,
        planets: [
            UniverseSceneSnapshot.followCameraTestPacket(
                name: "Mercury",
                worldPosition: .zero,
                framingRadius: mercuryRadius
            )
        ]
    )

    let minimumDistance = mode.minimumDistance(
        followingPlanetName: "Mercury",
        snapshot: snapshot,
        baseMinimumDistance: 0.001
    )
    let nearPlane = CameraFit.nearPlaneDistance(cameraDistance: minimumDistance,
                                                framingRadius: mercuryRadius)

    #expect(abs(minimumDistance - (mercuryRadius + CameraFit.minimumNearPlane * 2)) < 0.000001)
    #expect(nearPlane < minimumDistance - mercuryRadius)
}

extension UniverseSceneSnapshot {
    static var followCameraTestSnapshot: UniverseSceneSnapshot {
        UniverseSceneSnapshot(frameID: 1,
                               simulationTime: 0,
                               planets: [
                                followCameraTestPacket(name: "Sun",
                                                       worldPosition: SIMD3<Float>(0, 0, 0),
                                                       framingRadius: 0.2),
                                followCameraTestPacket(name: "Mars",
                                                       worldPosition: SIMD3<Float>(1.52, 0, 0),
                                                       framingRadius: 0.05)
                               ])
    }

    static func followCameraTestPacket(name: String,
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
