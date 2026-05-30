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
}

@MainActor
private final class FakeFollowCameraSnapshotSource: PreparedRenderSnapshotProviding {
    var latestSnapshot: PreparedRenderSnapshot?

    init(latestSnapshot: PreparedRenderSnapshot?) {
        self.latestSnapshot = latestSnapshot
    }

    func requestPreparation(simulationTime: Float) {}
}
