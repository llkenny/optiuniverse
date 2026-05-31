import CoreGraphics
import Foundation
import simd
import Testing
@testable import MetalModule

@MainActor
@Test func snapshotProviderReturnsLatestPreparedSnapshot() {
    let snapshot = PreparedRenderSnapshot(frameID: 7,
                                          simulationTime: 12,
                                          planets: [])
    let source = FakePreparedRenderSnapshotSource(latestSnapshot: snapshot)
    let provider = SnapshotProvider(snapshotSource: source)

    #expect(provider.latestSnapshot?.frameID == 7)
    #expect(provider.latestSnapshot?.simulationTime == 12)
}

@MainActor
@Test func snapshotProviderForwardsPreparationRequests() {
    let source = FakePreparedRenderSnapshotSource()
    let provider = SnapshotProvider(snapshotSource: source)

    provider.requestPreparation(simulationTime: 42)

    #expect(source.requestedSimulationTimes == [42])
}

@MainActor
@Test func snapshotProviderUsesExplicitProjectionParameters() {
    let source = FakePreparedRenderSnapshotSource()
    let provider = SnapshotProvider(snapshotSource: source)
    let viewportSize = CGSize(width: 200, height: 100)
    let projection = CameraProjectionParameters(nearPlane: 0.25,
                                                farPlane: 42)

    let cameraSnapshot = provider.makeCameraSnapshot(
        dependencies: makeDependencies(viewportSize: viewportSize,
                                       projection: projection)
    )
    let expectedProjection = float4x4.perspective(fov: CameraFit.verticalFieldOfView,
                                                  aspect: 2,
                                                  near: projection.nearPlane,
                                                  far: projection.farPlane)

    expectMatrix(cameraSnapshot.projectionMatrix,
                 equals: expectedProjection)
}

@MainActor
@Test func snapshotProviderReusesEquivalentSnapshotForUnchangedDependencies() {
    let cameraState = CameraState()
    let source = FakePreparedRenderSnapshotSource(
        latestSnapshot: PreparedRenderSnapshot(frameID: 1,
                                               simulationTime: 0,
                                               planets: [])
    )
    let provider = SnapshotProvider(cameraState: cameraState,
                                    snapshotSource: source)
    let projection = CameraProjectionParameters(nearPlane: 0.1,
                                                farPlane: 100)

    let dependencies = makeDependencies(sceneFrameID: source.latestSnapshot?.frameID,
                                        viewportSize: CGSize(width: 200, height: 100),
                                        projection: projection)
    let firstSnapshot = provider.makeCameraSnapshot(dependencies: dependencies)
    let secondSnapshot = provider.makeCameraSnapshot(dependencies: dependencies)

    expectCameraSnapshot(secondSnapshot,
                         equals: firstSnapshot)
}

@MainActor
@Test func snapshotProviderInvalidatesCacheWhenCameraRevisionChanges() {
    let cameraState = CameraState()
    let source = FakePreparedRenderSnapshotSource(
        latestSnapshot: PreparedRenderSnapshot(frameID: 1,
                                               simulationTime: 0,
                                               planets: [])
    )
    let provider = SnapshotProvider(cameraState: cameraState,
                                    snapshotSource: source)
    let projection = CameraProjectionParameters(nearPlane: 0.1,
                                                farPlane: 100)
    let dependencies = makeDependencies(sceneFrameID: source.latestSnapshot?.frameID,
                                        viewportSize: CGSize(width: 200, height: 100),
                                        projection: projection)
    let firstSnapshot = provider.makeCameraSnapshot(dependencies: dependencies)

    cameraState.commit(CameraState.Transaction(cameraDistance: 4))
    let secondSnapshot = provider.makeCameraSnapshot(dependencies: dependencies)

    #expect(secondSnapshot.cameraRevision == firstSnapshot.cameraRevision + 1)
    #expect(secondSnapshot.cameraDirtyFields == [.distance])
    expectVector(secondSnapshot.cameraOffset,
                 equals: SIMD3<Float>(0, 0, 4))
}

@MainActor
@Test func snapshotProviderInvalidatesCacheWhenSceneFrameChanges() {
    let source = FakePreparedRenderSnapshotSource(
        latestSnapshot: PreparedRenderSnapshot(frameID: 1,
                                               simulationTime: 0,
                                               planets: [])
    )
    let provider = SnapshotProvider(snapshotSource: source)
    let projection = CameraProjectionParameters(nearPlane: 0.1,
                                                farPlane: 100)
    let firstSnapshot = provider.makeCameraSnapshot(
        dependencies: makeDependencies(sceneFrameID: source.latestSnapshot?.frameID,
                                       viewportSize: CGSize(width: 200, height: 100),
                                       projection: projection)
    )

    source.latestSnapshot = PreparedRenderSnapshot(frameID: 2,
                                                   simulationTime: 1,
                                                   planets: [])
    let secondSnapshot = provider.makeCameraSnapshot(
        dependencies: makeDependencies(sceneFrameID: source.latestSnapshot?.frameID,
                                       viewportSize: CGSize(width: 200, height: 100),
                                       projection: projection)
    )

    #expect(firstSnapshot.sceneFrameID == 1)
    #expect(secondSnapshot.sceneFrameID == 2)
}

@MainActor
@Test func snapshotProviderInvalidatesCacheWhenViewportOrProjectionChanges() {
    let provider = SnapshotProvider(snapshotSource: FakePreparedRenderSnapshotSource())
    let projection = CameraProjectionParameters(nearPlane: 0.1,
                                                farPlane: 100)
    let firstSnapshot = provider.makeCameraSnapshot(
        dependencies: makeDependencies(viewportSize: CGSize(width: 200, height: 100),
                                       projection: projection)
    )

    let viewportSnapshot = provider.makeCameraSnapshot(
        dependencies: makeDependencies(viewportSize: CGSize(width: 100, height: 100),
                                       projection: projection)
    )
    let nearPlaneSnapshot = provider.makeCameraSnapshot(
        dependencies: makeDependencies(viewportSize: CGSize(width: 100, height: 100),
                                       projection: CameraProjectionParameters(nearPlane: 0.2,
                                                                              farPlane: 100))
    )
    let farPlaneSnapshot = provider.makeCameraSnapshot(
        dependencies: makeDependencies(viewportSize: CGSize(width: 100, height: 100),
                                       projection: CameraProjectionParameters(nearPlane: 0.2,
                                                                              farPlane: 200))
    )

    #expect(viewportSnapshot.viewportSize == CGSize(width: 100, height: 100))
    #expect(viewportSnapshot.projectionMatrix[0][0] != firstSnapshot.projectionMatrix[0][0])
    #expect(nearPlaneSnapshot.projectionMatrix[2][2] != viewportSnapshot.projectionMatrix[2][2])
    #expect(farPlaneSnapshot.projectionMatrix[2][2] != nearPlaneSnapshot.projectionMatrix[2][2])
}

@MainActor
@Test func snapshotProviderInvalidatesCacheWhenFollowedObjectSignatureChanges() {
    let provider = SnapshotProvider(snapshotSource: FakePreparedRenderSnapshotSource())
    let projection = CameraProjectionParameters(nearPlane: 0.1,
                                                farPlane: 100)
    let firstDependency = CameraFollowSnapshotDependency(
        planetName: "Mars",
        worldPosition: SIMD3<Float>(1, 0, 0),
        framingRadius: 0.1,
        hasActiveTransition: false
    )
    let secondDependency = CameraFollowSnapshotDependency(
        planetName: "Mars",
        worldPosition: SIMD3<Float>(2, 0, 0),
        framingRadius: 0.1,
        hasActiveTransition: false
    )

    let firstSnapshot = provider.makeCameraSnapshot(
        dependencies: makeDependencies(followedObject: firstDependency,
                                       projection: projection)
    )
    let secondSnapshot = provider.makeCameraSnapshot(
        dependencies: makeDependencies(followedObject: secondDependency,
                                       projection: projection)
    )

    #expect(firstSnapshot.dependencies.followedObject == firstDependency)
    #expect(secondSnapshot.dependencies.followedObject == secondDependency)
}

@MainActor
@Test func snapshotProviderInvalidatesCacheWhenNavigationRouteChanges() {
    let provider = SnapshotProvider(snapshotSource: FakePreparedRenderSnapshotSource())
    let projection = CameraProjectionParameters(nearPlane: 0.1,
                                                farPlane: 100)
    let routeID = UUID()
    let firstNavigation = CameraNavigationSnapshotDependency(routeID: routeID,
                                                            destinationName: "Mars",
                                                            progress: 0.1,
                                                            state: .running,
                                                            hasActiveTransition: false,
                                                            arrivalProgress: 1)
    let secondNavigation = CameraNavigationSnapshotDependency(routeID: routeID,
                                                             destinationName: "Mars",
                                                             progress: 0.2,
                                                             state: .running,
                                                             hasActiveTransition: false,
                                                             arrivalProgress: 1)

    let firstSnapshot = provider.makeCameraSnapshot(
        dependencies: makeDependencies(navigation: firstNavigation,
                                       projection: projection)
    )
    let secondSnapshot = provider.makeCameraSnapshot(
        dependencies: makeDependencies(navigation: secondNavigation,
                                       projection: projection)
    )

    #expect(firstSnapshot.dependencies.navigation == firstNavigation)
    #expect(secondSnapshot.dependencies.navigation == secondNavigation)
}

@MainActor
@Test func snapshotProviderInvalidatesCacheWhenActiveMotionRevisionChanges() {
    let provider = SnapshotProvider(snapshotSource: FakePreparedRenderSnapshotSource())
    let projection = CameraProjectionParameters(nearPlane: 0.1,
                                                farPlane: 100)

    let firstSnapshot = provider.makeCameraSnapshot(
        dependencies: makeDependencies(activeCameraMotionRevision: 1,
                                       projection: projection)
    )
    let secondSnapshot = provider.makeCameraSnapshot(
        dependencies: makeDependencies(activeCameraMotionRevision: 2,
                                       projection: projection)
    )

    #expect(firstSnapshot.dependencies.activeCameraMotionRevision == 1)
    #expect(secondSnapshot.dependencies.activeCameraMotionRevision == 2)
}

@MainActor
@Test func snapshotProviderDerivesSnapshotFromCanonicalCameraPose() {
    let cameraState = CameraState()
    let source = FakePreparedRenderSnapshotSource()
    let provider = SnapshotProvider(cameraState: cameraState,
                                    snapshotSource: source)
    let orientation = simd_quatf(angle: .pi / 2,
                                 axis: SIMD3<Float>(0, 1, 0))
    cameraState.commit(CameraState.Transaction(cameraTarget: SIMD3<Float>(1, 2, 3),
                                               cameraDistance: 5,
                                               cameraOrientation: orientation))

    let cameraSnapshot = provider.makeCameraSnapshot(
        dependencies: makeDependencies(viewportSize: CGSize(width: 200, height: 100),
                                       projection: CameraProjectionParameters(nearPlane: 0.1,
                                                                              farPlane: 100))
    )
    let expectedPose = cameraState.pose

    expectVector(cameraSnapshot.sceneOrigin,
                 equals: expectedPose.target)
    expectVector(cameraSnapshot.cameraOffset,
                 equals: expectedPose.offset)
    expectVector(cameraSnapshot.cameraWorldPosition,
                 equals: expectedPose.position)
    expectMatrix(cameraSnapshot.renderViewMatrix,
                 equals: expectedPose.makeRenderViewMatrix())
}

@MainActor
private final class FakePreparedRenderSnapshotSource: PreparedRenderSnapshotProviding {
    var latestSnapshot: PreparedRenderSnapshot?
    var requestedSimulationTimes: [Float] = []

    init(latestSnapshot: PreparedRenderSnapshot? = nil) {
        self.latestSnapshot = latestSnapshot
    }

    func requestPreparation(simulationTime: Float) {
        requestedSimulationTimes.append(simulationTime)
    }
}

private func expectMatrix(_ lhs: float4x4,
                          equals rhs: float4x4,
                          tolerance: Float = 0.000001) {
    for column in 0..<4 {
        for row in 0..<4 {
            #expect(abs(lhs[column][row] - rhs[column][row]) <= tolerance)
        }
    }
}

private func expectCameraSnapshot(_ lhs: SnapshotProvider.CameraSnapshot,
                                  equals rhs: SnapshotProvider.CameraSnapshot,
                                  tolerance: Float = 0.000001) {
    expectMatrix(lhs.renderViewMatrix,
                 equals: rhs.renderViewMatrix,
                 tolerance: tolerance)
    expectMatrix(lhs.projectionMatrix,
                 equals: rhs.projectionMatrix,
                 tolerance: tolerance)
    expectVector(lhs.sceneOrigin,
                 equals: rhs.sceneOrigin,
                 tolerance: tolerance)
    expectVector(lhs.cameraOffset,
                 equals: rhs.cameraOffset,
                 tolerance: tolerance)
    expectVector(lhs.cameraWorldPosition,
                 equals: rhs.cameraWorldPosition,
                 tolerance: tolerance)
    #expect(lhs.viewportSize == rhs.viewportSize)
    #expect(lhs.cameraRevision == rhs.cameraRevision)
    #expect(lhs.cameraDirtyFields == rhs.cameraDirtyFields)
    #expect(lhs.sceneFrameID == rhs.sceneFrameID)
    #expect(lhs.dependencies == rhs.dependencies)
}

private func makeDependencies(followedObject: CameraFollowSnapshotDependency? = nil,
                              navigation: CameraNavigationSnapshotDependency? = nil,
                              transfer: CameraTransferSnapshotDependency? = nil,
                              activeCameraMotionRevision: Int = 0,
                              sceneFrameID: UInt64? = nil,
                              viewportSize: CGSize = CGSize(width: 200, height: 100),
                              projection: CameraProjectionParameters) -> CameraSnapshotDependencies {
    CameraSnapshotDependencies(followedObject: followedObject,
                               navigation: navigation,
                               transfer: transfer,
                               activeCameraMotionRevision: activeCameraMotionRevision,
                               sceneFrameID: sceneFrameID,
                               viewportSize: viewportSize,
                               projection: projection)
}

private func expectVector(_ lhs: SIMD3<Float>,
                          equals rhs: SIMD3<Float>,
                          tolerance: Float = 0.000001) {
    #expect(abs(lhs.x - rhs.x) <= tolerance)
    #expect(abs(lhs.y - rhs.y) <= tolerance)
    #expect(abs(lhs.z - rhs.z) <= tolerance)
}
