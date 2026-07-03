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
@Test func navigationControllerUpdateKeepsRouteGeometryStableWhileProgressAdvances() throws {
    let playback = AdvancingRoutePlayback(progressAfterUpdate: 0.5)
    let fixture = NavigationControllerFixture(routePlayback: playback)

    fixture.controller.startNavigation(to: "Mars")
    let initialPoints = try #require(fixture.controller.routeRenderState.route?.points)

    fixture.controller.update(snapshot: .movedDestinationSnapshot,
                              delta: 0.1)

    #expect(fixture.controller.routeRenderState.progress == 0.5)
    #expect(fixture.controller.routeRenderState.route?.points == initialPoints)
}

@MainActor
@Test func navigationControllerManualCameraControlDisablesAutoFramingButKeepsRouteActive() throws {
    let fixture = NavigationControllerFixture()

    fixture.controller.startNavigation(to: "Mars")
    #expect(fixture.controller.routeRenderState.isCameraAutoFramingEnabled)

    fixture.controller.beginManualCameraControl()

    #expect(!fixture.controller.routeRenderState.isCameraAutoFramingEnabled)
    #expect(fixture.controller.routeRenderState.route != nil)
    #expect(fixture.controller.navigationSnapshot.state == .running)
}

@MainActor
@Test func navigationControllerStartResetsCameraAutoFraming() throws {
    let fixture = NavigationControllerFixture()

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.beginManualCameraControl()
    #expect(!fixture.controller.routeRenderState.isCameraAutoFramingEnabled)

    fixture.controller.cancelNavigation()
    fixture.controller.startNavigation(to: "Mars")

    #expect(fixture.controller.routeRenderState.isCameraAutoFramingEnabled)
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
@Test func navigationControllerKeepsAutoFramingDuringCompletedHold() {
    let playback = CompletingRoutePlayback()
    let fixture = NavigationControllerFixture(routePlayback: playback)

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.update(snapshot: fixture.snapshot,
                              delta: 0.1)

    #expect(fixture.controller.navigationSnapshot.state == .completed)
    #expect(fixture.controller.routeRenderState.isCameraAutoFramingEnabled)
    #expect(fixture.controller.routeRenderState.progress == 1)
}

@MainActor
@Test func navigationControllerDonePublishesCompletedDestinationHandoff() {
    let playback = CompletingRoutePlayback()
    let fixture = NavigationControllerFixture(routePlayback: playback)
    var completedDestinationName: String?
    fixture.controller.navigationDidComplete = { completedDestinationName = $0 }

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.update(snapshot: fixture.snapshot,
                              delta: 0.1)
    fixture.controller.doneNavigation()

    #expect(completedDestinationName == "Mars")
    #expect(fixture.controller.navigationSnapshot.state == .cancelled)
}

@MainActor
@Test func navigationControllerCancelDoesNotPublishCompletedDestinationHandoff() {
    let fixture = NavigationControllerFixture()
    var completedDestinationName: String?
    fixture.controller.navigationDidComplete = { completedDestinationName = $0 }

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.cancelNavigation()

    #expect(completedDestinationName == nil)
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

private final class AdvancingRoutePlayback: RoutePlayback {
    private let progressAfterUpdate: Float
    private(set) var progress: Float = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var isCompleted = false

    init(progressAfterUpdate: Float) {
        self.progressAfterUpdate = progressAfterUpdate
    }

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

    func update() {
        progress = progressAfterUpdate
        elapsedTime = TimeInterval(progressAfterUpdate)
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

    static var movedDestinationSnapshot: UniverseSceneSnapshot {
        UniverseSceneSnapshot(frameID: 2,
                               simulationTime: 1,
                               planets: [
                                testPacket(name: "Sun",
                                           worldPosition: SIMD3<Float>(0, 0, 0),
                                           framingRadius: 0.2),
                                testPacket(name: "Earth",
                                           worldPosition: SIMD3<Float>(1, 0, 0),
                                           framingRadius: 0.05),
                                testPacket(name: "Mars",
                                           worldPosition: SIMD3<Float>(0, 0, -1.52),
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
