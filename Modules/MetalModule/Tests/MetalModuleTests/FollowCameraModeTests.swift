import CoreGraphics
import simd
import Testing
@testable import MetalModule

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

extension PreparedRenderSnapshot {
    static var followCameraTestSnapshot: PreparedRenderSnapshot {
        PreparedRenderSnapshot(frameID: 1,
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
                                       framingRadius: Float) -> PreparedPlanetRenderPacket {
        PreparedPlanetRenderPacket(planetName: name,
                                   meshes: [],
                                   baseModelMatrix: matrix_identity_float4x4,
                                   worldModelMatrix: matrix_identity_float4x4,
                                   normalizedScale: 1,
                                   primaryMeshRadius: framingRadius,
                                   framingRadius: framingRadius,
                                   worldPosition: worldPosition)
    }
}
