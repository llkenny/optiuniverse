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
@Test func navigationControllerStartDoesNotMutateCameraState() {
    let fixture = NavigationControllerFixture()
    let initialRevision = fixture.cameraState.revision
    let initialPose = fixture.cameraState.pose

    fixture.controller.startNavigation(to: "Mars")

    #expect(fixture.cameraState.revision == initialRevision)
    #expect(fixture.cameraState.pose == initialPose)
}

@MainActor
@Test func navigationControllerCancelDoesNotMutateCameraState() {
    let fixture = NavigationControllerFixture()
    let initialRevision = fixture.cameraState.revision
    let initialPose = fixture.cameraState.pose

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.cancelNavigation()

    #expect(fixture.controller.navigationSnapshot.state == .cancelled)
    #expect(fixture.cameraState.revision == initialRevision)
    #expect(fixture.cameraState.pose == initialPose)
}

@MainActor
@Test func navigationControllerUpdateDoesNotMutateCameraState() {
    let fixture = NavigationControllerFixture()
    let initialRevision = fixture.cameraState.revision
    let initialPose = fixture.cameraState.pose

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.update(snapshot: fixture.snapshot,
                              delta: 0.1)

    #expect(fixture.cameraState.revision == initialRevision)
    #expect(fixture.cameraState.pose == initialPose)
}

@MainActor
@Test func navigationControllerPublishesObservableFacadeStateChanges() {
    let fixture = NavigationControllerFixture()
    var snapshots: [NavigationRouteSnapshot] = []
    fixture.controller.navigationSnapshotDidChange = { snapshots.append($0) }

    fixture.controller.startNavigation(to: "Mars")

    #expect(snapshots.contains { $0.state == .running && $0.destinationName == "Mars" })
}

@MainActor
@Test func navigationControllerDoneDoesNotMutateCameraState() {
    let playback = CompletingRoutePlayback()
    let fixture = NavigationControllerFixture(routePlayback: playback)

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.update(snapshot: fixture.snapshot,
                              delta: 0.1)
    let initialRevision = fixture.cameraState.revision
    let initialPose = fixture.cameraState.pose

    fixture.controller.doneNavigation()

    #expect(fixture.controller.navigationSnapshot.state == .cancelled)
    #expect(fixture.cameraState.revision == initialRevision)
    #expect(fixture.cameraState.pose == initialPose)
}

@MainActor
private struct NavigationControllerFixture {
    let snapshot = UniverseSceneSnapshot.navigationControllerTestSnapshot
    let source: FakeNavigationSnapshotSource
    let provider: SnapshotProvider
    let cameraState: CameraState
    let controller: NavigationController

    init(routePlayback: RoutePlayback = RoutePlaybackController()) {
        source = FakeNavigationSnapshotSource(latestSnapshot: snapshot)
        cameraState = CameraState()
        provider = SnapshotProvider(cameraState: cameraState,
                                    snapshotSource: source)
        controller = NavigationController(snapshotProvider: provider,
                                          planets: testPlanets,
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
private final class FakeNavigationSnapshotSource: UniverseSceneSnapshotProviding {
    var latestSnapshot: UniverseSceneSnapshot?

    init(latestSnapshot: UniverseSceneSnapshot?) {
        self.latestSnapshot = latestSnapshot
    }

    func requestPreparation(simulationTime: Float) {}
}

private extension UniverseSceneSnapshot {
    static var navigationControllerTestSnapshot: UniverseSceneSnapshot {
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
