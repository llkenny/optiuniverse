import CoreGraphics
import simd
import Testing
@testable import MetalModule

@MainActor
@Test func navigationControllerStartsRouteAndExposesRenderState() throws {
    let fixture = NavigationControllerFixture()

    fixture.controller.startNavigation(to: "Mars")

    #expect(fixture.publisher.navigationSnapshot.state == .running)
    #expect(fixture.controller.routeRenderState.route?.destinationName == "Mars")
    #expect(fixture.controller.routeRenderState.progress == 0)
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

    #expect(fixture.publisher.navigationSnapshot.state == .cancelled)
    #expect(followedPlanets == ["Mars"])
}

@MainActor
@Test func navigationControllerDisablingFollowUsesOverviewCameraTransition() {
    let fixture = NavigationControllerFixture()

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.setNavigationCameraFollowEnabled(false)
    fixture.controller.update(snapshot: fixture.snapshot,
                              delta: 0.1)

    #expect(fixture.publisher.navigationCameraFollowEnabled == false)
    #expect(fixture.cameraCoordinator.isNavigationCameraActive)
}

@MainActor
private struct NavigationControllerFixture {
    let snapshot = PreparedRenderSnapshot.navigationControllerTestSnapshot
    let publisher = FakeNavigationStatePublisher()
    let source: FakeNavigationSnapshotSource
    let provider: SnapshotProvider
    let cameraState: CameraState
    let cameraCoordinator: CameraCoordinator
    let controller: NavigationController

    init() {
        source = FakeNavigationSnapshotSource(latestSnapshot: snapshot)
        cameraState = CameraState()
        provider = SnapshotProvider(cameraState: cameraState,
                                    snapshotSource: source)
        cameraCoordinator = CameraCoordinator(cameraState: cameraState)
        controller = NavigationController(navigationStatePublisher: publisher,
                                          snapshotProvider: provider,
                                          cameraCoordinator: cameraCoordinator,
                                          planets: testPlanets,
                                          viewportSize: { CGSize(width: 390, height: 844) })
    }
}

@MainActor
private final class FakeNavigationStatePublisher: NavigationRenderStatePublishing {
    var navigationSnapshot: NavigationRouteSnapshot = .idle
    var navigationCameraFollowEnabled = true

    func publishNavigationSnapshot(_ snapshot: NavigationRouteSnapshot) {
        navigationSnapshot = snapshot
    }

    func publishNavigationCameraFollowEnabled(_ isEnabled: Bool) {
        navigationCameraFollowEnabled = isEnabled
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
                                   worldPosition: worldPosition)
    }
}
