import CoreGraphics
import simd
import Testing
@testable import MetalModule

@MainActor
@Test func followCameraOwnerStartsImmediateFollowTransition() {
    let fixture = FollowCameraOwnerFixture()
    let initialRevision = fixture.cameraState.revision

    fixture.owner.followPlanet(named: "Mars",
                               viewportSize: fixture.viewportSize)
    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: 0.1,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: false)

    #expect(fixture.cameraState.revision == initialRevision + 1)
    #expect(fixture.cameraState.cameraTarget.x > 0)
}

@MainActor
@Test func followCameraOwnerPendingFollowResolvesOnSnapshotUpdate() {
    let fixture = FollowCameraOwnerFixture(latestSnapshot: nil)

    fixture.owner.followPlanet(named: "Mars",
                               viewportSize: fixture.viewportSize)
    #expect(fixture.cameraState.revision == 0)

    fixture.source.latestSnapshot = .followCameraTestSnapshot
    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: 0.1,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: false)

    #expect(fixture.cameraState.revision == 1)
    #expect(fixture.cameraState.cameraTarget.x > 0)
}

@MainActor
@Test func followCameraOwnerManualControlClearsTransitionButKeepsFollowTarget() {
    let fixture = FollowCameraOwnerFixture()

    fixture.owner.followPlanet(named: "Mars",
                               viewportSize: fixture.viewportSize)
    fixture.owner.beginManualCameraControl()
    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: 0.1,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: false)

    #expect(fixture.cameraState.cameraTarget == SIMD3<Float>(1.52, 0, 0))
    #expect(fixture.cameraState.cameraDistance == 3)
}

@MainActor
@Test func followCameraOwnerSuppressedUpdateDoesNotCommitFollowCamera() {
    let fixture = FollowCameraOwnerFixture()

    fixture.owner.followPlanet(named: "Mars",
                               viewportSize: fixture.viewportSize)
    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: 0.1,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: true)

    #expect(fixture.cameraState.revision == 0)
    #expect(fixture.cameraState.cameraTarget == SIMD3<Float>(0, 0, 0))
}

@MainActor
@Test func followCameraOwnerProjectionUsesFollowedPlanetRadius() {
    let fixture = FollowCameraOwnerFixture()
    fixture.owner.followPlanet(named: "Mars",
                               viewportSize: fixture.viewportSize)
    fixture.cameraState.commit(CameraState.Transaction(cameraDistance: 0.08))
    let projection = fixture.owner.projectionParameters(
        snapshot: fixture.source.latestSnapshot,
        baseProjection: CameraProjectionParameters(nearPlane: 0.1,
                                                   farPlane: 10000)
    )

    #expect(projection.nearPlane < CameraFit.defaultNearPlane)
    #expect(projection.farPlane == 10000)
}

@MainActor
@Test func followCameraOwnerSurfaceFollowRunsBodyTransitionFirst() {
    let fixture = FollowCameraOwnerFixture(latestSnapshot: .surfaceFollowTestSnapshot)
    let coordinate = SurfaceCoordinate(latitudeDegrees: -90,
                                       longitudeDegrees: 0)
    let expectedDistance = CameraFit.distanceToFit(radius: 0.5,
                                                   currentDistance: 3,
                                                   viewportSize: fixture.viewportSize)

    fixture.owner.followPlanet(named: "Moon",
                               surfaceCoordinate: coordinate,
                               viewportSize: fixture.viewportSize)
    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: 0.1,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: false)

    #expect(fixture.cameraState.cameraTarget != surfaceMoonCenter)
    #expect(fixture.cameraState.lastDirtyFields.contains(.target))
    #expect(fixture.cameraState.lastDirtyFields.contains(.distance))
    #expect(!fixture.cameraState.lastDirtyFields.contains(.orientation))

    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: fixture.cameraState.cameraFollowTransitionDuration,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: false)

    expectSurfaceVector(fixture.cameraState.cameraTarget,
                 equals: surfaceMoonCenter)
    expectSurfaceEqual(fixture.cameraState.cameraDistance,
                expectedDistance)
}

@MainActor
@Test func followCameraOwnerSurfaceRotationKeepsBodyCenterAndDistance() {
    let fixture = FollowCameraOwnerFixture(latestSnapshot: .surfaceFollowTestSnapshot)
    let expectedDistance = fixture.startSurfaceFollowAndCompleteBodyTransition()

    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: 0.1,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: false)

    expectSurfaceVector(fixture.cameraState.cameraTarget,
                 equals: surfaceMoonCenter)
    expectSurfaceEqual(fixture.cameraState.cameraDistance,
                expectedDistance)
    #expect(fixture.cameraState.lastDirtyFields == .orientation)
}

@MainActor
@Test func followCameraOwnerSurfaceZoomHalvesDistanceAfterRotation() throws {
    let fixture = FollowCameraOwnerFixture(latestSnapshot: .surfaceFollowTestSnapshot)
    let bodyFollowDistance = fixture.startSurfaceFollowAndCompleteBodyTransition()

    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: fixture.cameraState.cameraFollowTransitionDuration,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: false)
    expectSurfaceEqual(fixture.cameraState.cameraDistance,
                bodyFollowDistance)

    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: fixture.cameraState.cameraFollowTransitionDuration,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: false)

    expectSurfaceVector(fixture.cameraState.cameraTarget,
                 equals: surfaceMoonCenter)
    expectSurfaceEqual(fixture.cameraState.cameraDistance,
                bodyFollowDistance * 0.5)
    try expectCurrentCameraAlignedWithMoonSouthPole(fixture.cameraState)
}

@MainActor
@Test func followCameraOwnerRepeatedSurfaceFollowSkipsRedundantBodyTransition() {
    let fixture = FollowCameraOwnerFixture(latestSnapshot: .surfaceFollowTestSnapshot)
    _ = fixture.startSurfaceFollowAndCompleteBodyTransition()
    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: fixture.cameraState.cameraFollowTransitionDuration,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: false)
    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: fixture.cameraState.cameraFollowTransitionDuration,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: false)
    let settledDistance = fixture.cameraState.cameraDistance
    fixture.cameraState.commit(CameraState.Transaction(
        cameraOrientation: simd_quatf(angle: 0,
                                      axis: SIMD3<Float>(0, 1, 0))
    ))
    let revisionBeforeRepeat = fixture.cameraState.revision

    fixture.owner.followPlanet(named: "Moon",
                               surfaceCoordinate: SurfaceCoordinate(latitudeDegrees: -90,
                                                                    longitudeDegrees: 0),
                               viewportSize: fixture.viewportSize)
    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: 0.1,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: false)

    expectSurfaceVector(fixture.cameraState.cameraTarget,
                        equals: surfaceMoonCenter)
    expectSurfaceEqual(fixture.cameraState.cameraDistance,
                       settledDistance)
    #expect(fixture.cameraState.revision == revisionBeforeRepeat)

    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: 0.1,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: false)

    expectSurfaceVector(fixture.cameraState.cameraTarget,
                        equals: surfaceMoonCenter)
    expectSurfaceEqual(fixture.cameraState.cameraDistance,
                       settledDistance)
    #expect(fixture.cameraState.lastDirtyFields == .orientation)
}

@MainActor
@Test func followCameraOwnerSuppressedSurfaceFollowDoesNotCommitCameraChanges() {
    let fixture = FollowCameraOwnerFixture(latestSnapshot: .surfaceFollowTestSnapshot)

    fixture.owner.followPlanet(named: "Moon",
                               surfaceCoordinate: SurfaceCoordinate(latitudeDegrees: -90,
                                                                    longitudeDegrees: 0),
                               viewportSize: fixture.viewportSize)
    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: fixture.cameraState.cameraFollowTransitionDuration,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: true)

    #expect(fixture.cameraState.revision == 0)
    expectSurfaceVector(fixture.cameraState.cameraTarget,
                 equals: .zero)
    expectSurfaceEqual(fixture.cameraState.cameraDistance,
                3)
}

@MainActor
@Test func followCameraOwnerManualControlCancelsSurfaceFocus() {
    let fixture = FollowCameraOwnerFixture(latestSnapshot: .surfaceFollowTestSnapshot)

    fixture.owner.followPlanet(named: "Moon",
                               surfaceCoordinate: SurfaceCoordinate(latitudeDegrees: -90,
                                                                    longitudeDegrees: 0),
                               viewportSize: fixture.viewportSize)
    fixture.owner.beginManualCameraControl()
    fixture.owner.update(snapshot: fixture.source.latestSnapshot,
                         delta: fixture.cameraState.cameraFollowTransitionDuration,
                         viewportSize: fixture.viewportSize,
                         isSuppressed: false)

    expectSurfaceVector(fixture.cameraState.cameraTarget,
                 equals: surfaceMoonCenter)
    expectSurfaceEqual(fixture.cameraState.cameraDistance,
                3)
    #expect(fixture.cameraState.cameraOrientation == simd_quatf(angle: 0,
                                                               axis: SIMD3<Float>(0, 1, 0)))
}

@MainActor
private struct FollowCameraOwnerFixture {
    let viewportSize = CGSize(width: 390, height: 844)
    let source: FakeFollowCameraSnapshotSource
    let provider: SnapshotProvider
    let cameraState: CameraState
    let owner: FollowCameraOwner

    init(latestSnapshot: PreparedRenderSnapshot? = .followCameraTestSnapshot) {
        source = FakeFollowCameraSnapshotSource(latestSnapshot: latestSnapshot)
        cameraState = CameraState()
        provider = SnapshotProvider(cameraState: cameraState,
                                    snapshotSource: source)
        owner = FollowCameraOwner(cameraState: cameraState,
                                  snapshotProvider: provider)
    }

    @discardableResult
    func startSurfaceFollowAndCompleteBodyTransition() -> Float {
        let expectedDistance = CameraFit.distanceToFit(radius: 0.5,
                                                       currentDistance: cameraState.cameraDistance,
                                                       viewportSize: viewportSize)
        owner.followPlanet(named: "Moon",
                           surfaceCoordinate: SurfaceCoordinate(latitudeDegrees: -90,
                                                                longitudeDegrees: 0),
                           viewportSize: viewportSize)
        owner.update(snapshot: source.latestSnapshot,
                     delta: cameraState.cameraFollowTransitionDuration,
                     viewportSize: viewportSize,
                     isSuppressed: false)
        expectSurfaceVector(cameraState.cameraTarget,
                     equals: surfaceMoonCenter)
        expectSurfaceEqual(cameraState.cameraDistance,
                    expectedDistance)
        return expectedDistance
    }
}

@MainActor
private final class FakeFollowCameraSnapshotSource: PreparedRenderSnapshotProviding {
    var latestSnapshot: PreparedRenderSnapshot?

    init(latestSnapshot: PreparedRenderSnapshot?) {
        self.latestSnapshot = latestSnapshot
    }

    func requestPreparation(simulationTime: Float) {}
}

private let surfaceMoonCenter = SIMD3<Float>(2, 0, 0)

private extension PreparedRenderSnapshot {
    static var surfaceFollowTestSnapshot: PreparedRenderSnapshot {
        PreparedRenderSnapshot(frameID: 1,
                               simulationTime: 0,
                               planets: [
                                surfaceCameraTestPacket(name: "Moon",
                                                        worldPosition: surfaceMoonCenter,
                                                        radius: 0.5)
                               ])
    }
}

private func expectCurrentCameraAlignedWithMoonSouthPole(_ cameraState: CameraState) throws {
    let planet = try #require(PreparedRenderSnapshot.surfaceFollowTestSnapshot.planet(named: "Moon"))
    let surfacePoint = SurfaceCoordinateMath.worldSurfacePoint(
        on: planet,
        at: SurfaceCoordinate(latitudeDegrees: -90,
                              longitudeDegrees: 0)
    )
    let cameraToSurface = surfacePoint - cameraState.pose.position
    let surfaceToCenter = planet.worldPosition - surfacePoint

    expectSurfaceEqual(simd_length(simd_cross(cameraToSurface, surfaceToCenter)),
                0,
                tolerance: 0.00001)
    #expect(simd_dot(simd_normalize(cameraToSurface),
                    simd_normalize(surfaceToCenter)) > 0.999)
}
