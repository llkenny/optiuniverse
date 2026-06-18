import CoreGraphics
import Foundation
import simd
import Testing
@testable import UniverseModule

@MainActor
@Test func navigationControllerStartsRouteAndExposesRenderState() throws {
    let fixture = NavigationControllerFixture()

    fixture.controller.startNavigation(to: "Mars")

    #expect(fixture.controller.navigationSnapshot.state == .running)
    #expect(fixture.controller.routeRenderState.route?.destinationName == "Mars")
    #expect(fixture.controller.routeRenderState.progress < 0.001)
}

@MainActor
@Test func navigationControllerStartCommitsOneNavigationCameraTransaction() {
    let fixture = NavigationControllerFixture()
    let initialRevision = fixture.cameraState.revision

    fixture.controller.startNavigation(to: "Mars")

    #expect(fixture.cameraCoordinator.isNavigationCameraActive)
    #expect(fixture.cameraState.revision == initialRevision + 1)
}

@MainActor
@Test func navigationControllerCancelFollowsDestination() {
    let fixture = NavigationControllerFixture()
    var followedPlanets: [String] = []
    fixture.controller.followPlanet = { followedPlanets.append($0) }

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.cancelNavigation()

    #expect(fixture.controller.navigationSnapshot.state == .cancelled)
    #expect(followedPlanets == ["Mars"])
}

@MainActor
@Test func navigationControllerCancelRestoresDestinationFollowCamera() {
    let fixture = NavigationControllerFixture()
    fixture.controller.followPlanet = { name in
        fixture.cameraCoordinator.followNavigationDestination(named: name,
                                                              viewportSize: fixture.viewportSize)
    }

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.cancelNavigation()
    #expect(!fixture.cameraCoordinator.isNavigationCameraActive)

    fixture.cameraCoordinator.updateFrameCamera(
        snapshot: fixture.snapshot,
        delta: 1.2,
        viewportSize: fixture.viewportSize,
        modeState: CameraFrameModeState(navigationControlsCamera: false,
                                        navigation: nil,
                                        transferPreviewActive: false,
                                        transfer: nil)
    )

    let expectedDistance = CameraFit.distanceToFit(radius: 0.05,
                                                   currentDistance: fixture.cameraState.cameraDistance,
                                                   viewportSize: fixture.viewportSize)
    #expect(fixture.cameraState.cameraTarget == SIMD3<Float>(1.52, 0, 0))
    #expect(abs(fixture.cameraState.cameraDistance - expectedDistance) < 0.000001)
}

@MainActor
@Test func navigationControllerDisablingFollowUsesOverviewCameraTransition() {
    let fixture = NavigationControllerFixture()

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.setNavigationCameraFollowEnabled(false)
    fixture.controller.update(snapshot: fixture.snapshot,
                              delta: 0.1)

    #expect(fixture.controller.navigationCameraFollowEnabled == false)
    #expect(fixture.cameraCoordinator.isNavigationCameraActive)
}

@MainActor
@Test func navigationControllerManualControlReleasesNavigationCameraOwner() {
    let fixture = NavigationControllerFixture()

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.beginManualCameraControl()

    #expect(fixture.controller.navigationCameraFollowEnabled == false)
    #expect(!fixture.cameraCoordinator.isNavigationCameraActive)
}

@MainActor
@Test func navigationControllerPublishesObservableFacadeStateChanges() {
    let fixture = NavigationControllerFixture()
    var snapshots: [NavigationRouteSnapshot] = []
    var followStates: [Bool] = []
    fixture.controller.navigationSnapshotDidChange = { snapshots.append($0) }
    fixture.controller.navigationCameraFollowEnabledDidChange = { followStates.append($0) }

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.setNavigationCameraFollowEnabled(false)

    #expect(snapshots.contains { $0.state == .running && $0.destinationName == "Mars" })
    #expect(followStates == [false])
}

@MainActor
@Test func navigationControllerAppliesRouteProjectionParameters() {
    let fixture = NavigationControllerFixture()
    let baseProjection = CameraProjectionParameters(nearPlane: 0.03,
                                                    farPlane: 1)

    fixture.controller.startNavigation(to: "Mars")
    let followProjection = fixture.controller.projectionParameters(snapshot: fixture.snapshot,
                                                                  baseProjection: baseProjection)
    let expectedNearPlane = min(CameraFit.defaultNearPlane,
                                max(CameraFit.minimumNearPlane,
                                    (fixture.cameraCoordinator.cameraDistance - 0.05) * 0.5))

    #expect(abs(followProjection.nearPlane - expectedNearPlane) < 0.000001)
    #expect(followProjection.farPlane == CameraFit.defaultFarPlane)

    fixture.controller.setNavigationCameraFollowEnabled(false)
    let overviewProjection = fixture.controller.projectionParameters(snapshot: fixture.snapshot,
                                                                    baseProjection: baseProjection)

    #expect(overviewProjection.nearPlane == baseProjection.nearPlane)
    #expect(overviewProjection.farPlane == CameraFit.defaultFarPlane)
}

@MainActor
@Test func navigationControllerDonePreservesDestinationCameraBeforeFollowHandoff() {
    let playback = CompletingRoutePlayback()
    let fixture = NavigationControllerFixture(routePlayback: playback)
    var followedPlanets: [String] = []
    fixture.controller.followPlanet = { followedPlanets.append($0) }

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.update(snapshot: fixture.snapshot,
                              delta: 0.1)
    let revisionBeforeDone = fixture.cameraState.revision

    fixture.controller.doneNavigation()

    #expect(fixture.controller.navigationSnapshot.state == .cancelled)
    #expect(fixture.cameraState.revision > revisionBeforeDone)
    #expect(fixture.cameraState.cameraTarget == SIMD3<Float>(1.52, 0, 0))
    #expect(followedPlanets == ["Mars"])
}

@MainActor
private struct NavigationControllerFixture {
    let viewportSize = CGSize(width: 390, height: 844)
    let snapshot = PreparedRenderSnapshot.navigationControllerTestSnapshot
    let source: FakeNavigationSnapshotSource
    let provider: SnapshotProvider
    let cameraState: CameraState
    let cameraCoordinator: CameraCoordinator
    let controller: NavigationController

    init(routePlayback: RoutePlayback = RoutePlaybackController()) {
        let viewportSize = self.viewportSize
        source = FakeNavigationSnapshotSource(latestSnapshot: snapshot)
        cameraState = CameraState()
        provider = SnapshotProvider(cameraState: cameraState,
                                    snapshotSource: source)
        cameraCoordinator = CameraCoordinator(cameraState: cameraState,
                                              snapshotProvider: provider)
        controller = NavigationController(snapshotProvider: provider,
                                          cameraCoordinator: cameraCoordinator,
                                          planets: testPlanets,
                                          viewportSize: { viewportSize },
                                          routePlayback: routePlayback)
    }
}

private final class CompletingRoutePlayback: RoutePlayback {
    private(set) var progress: Float = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var isCompleted = false
    private var duration: TimeInterval = 1

    func start(duration: TimeInterval) {
        self.duration = duration
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

    func update() {
        progress = 1
        elapsedTime = duration
        isCompleted = true
    }
}

@MainActor
private final class FakeNavigationSnapshotSource: PreparedRenderSnapshotProviding {
    var latestSnapshot: PreparedRenderSnapshot?

    init(latestSnapshot: PreparedRenderSnapshot?) {
        self.latestSnapshot = latestSnapshot
    }

    func requestPreparation(simulationTime: Float) {}
}

private extension PreparedRenderSnapshot {
    static var navigationControllerTestSnapshot: PreparedRenderSnapshot {
        PreparedRenderSnapshot(frameID: 1,
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
                           framingRadius: Float) -> PreparedPlanetRenderPacket {
        PreparedPlanetRenderPacket(planetName: name,
                                   meshes: [],
                                   baseModelMatrix: matrix_identity_float4x4,
                                   worldModelMatrix: matrix_identity_float4x4,
                                   normalizedScale: 1,
                                   primaryMeshRadius: framingRadius,
                                   framingRadius: framingRadius,
                                   surfaceRadius: framingRadius,
                                   worldPosition: worldPosition)
    }
}
