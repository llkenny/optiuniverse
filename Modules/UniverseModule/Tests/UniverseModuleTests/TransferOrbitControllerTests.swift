import CoreGraphics
import simd
import Testing
@testable import UniverseModule

@MainActor
@Test func transferOrbitControllerShowCreatesActiveRenderState() throws {
    let fixture = TransferOrbitControllerFixture()

    fixture.controller.showTransferOrbit(to: "Mars")

    #expect(fixture.controller.isTransferPreviewActive)
    #expect(fixture.controller.renderState.transferOrbit?.destinationName == "Mars")
}

@MainActor
@Test func transferOrbitControllerPendingDestinationResolvesOnUpdate() throws {
    let fixture = TransferOrbitControllerFixture(latestSnapshot: nil)

    fixture.controller.showTransferOrbit(to: "Mars")
    #expect(!fixture.controller.isTransferPreviewActive)

    fixture.source.latestSnapshot = .transferOrbitControllerTestSnapshot
    fixture.controller.update(snapshot: fixture.source.latestSnapshot,
                              delta: 0.1)

    #expect(fixture.controller.isTransferPreviewActive)
    #expect(fixture.controller.renderState.transferOrbit?.destinationName == "Mars")
}

@MainActor
@Test func transferOrbitControllerInvalidDestinationClearsAndFollowsFallback() throws {
    let fixture = TransferOrbitControllerFixture()
    var followedPlanets: [String] = []
    fixture.controller.followPlanet = { followedPlanets.append($0) }

    fixture.controller.showTransferOrbit(to: "Earth")

    #expect(!fixture.controller.isTransferPreviewActive)
    #expect(fixture.controller.renderState == .inactive)
    #expect(followedPlanets == ["Earth"])
}

@MainActor
@Test func transferOrbitControllerOverviewTransitionCommitsCameraTransaction() throws {
    let fixture = TransferOrbitControllerFixture()
    let initialRevision = fixture.cameraState.revision

    fixture.controller.showTransferOrbit(to: "Mars")
    fixture.controller.update(snapshot: fixture.source.latestSnapshot,
                              delta: 0.1)

    #expect(fixture.cameraState.revision == initialRevision + 1)
}

@MainActor
@Test func transferOrbitControllerClearRemovesRenderStateAndPendingTransition() throws {
    let fixture = TransferOrbitControllerFixture()

    fixture.controller.showTransferOrbit(to: "Mars")
    fixture.controller.clearTransferOrbit()
    fixture.controller.update(snapshot: fixture.source.latestSnapshot,
                              delta: 0.1)

    #expect(!fixture.controller.isTransferPreviewActive)
    #expect(fixture.controller.renderState == .inactive)
}

@MainActor
@Test func transferOrbitControllerCancelRestoresDestinationFollowCamera() throws {
    let fixture = TransferOrbitControllerFixture()
    fixture.controller.followPlanet = { name in
        fixture.cameraCoordinator.followNavigationDestination(named: name,
                                                              viewportSize: fixture.viewportSize)
    }

    fixture.controller.showTransferOrbit(to: "Mars")
    fixture.controller.update(snapshot: fixture.source.latestSnapshot,
                              delta: 0.1)
    #expect(fixture.cameraState.cameraTarget != SIMD3<Float>(1.52, 0, 0))

    fixture.controller.cancelTransferOrbit()
    fixture.cameraCoordinator.updateFrameCamera(
        snapshot: fixture.source.latestSnapshot,
        delta: 1.2,
        viewportSize: fixture.viewportSize,
        modeState: CameraFrameModeState(navigationControlsCamera: false,
                                        navigation: nil,
                                        transferPreviewActive: false,
                                        transfer: nil)
    )

    #expect(!fixture.controller.isTransferPreviewActive)
    #expect(fixture.controller.renderState == .inactive)
    #expect(fixture.cameraState.cameraTarget == SIMD3<Float>(1.52, 0, 0))
}

@MainActor
@Test func sceneRouteRenderStateUsesTransferPreviewRenderState() throws {
    let fixture = TransferOrbitControllerFixture()

    fixture.controller.showTransferOrbit(to: "Mars")
    let routes = SceneRouteRenderState(
        transfer: fixture.controller.renderState,
        navigation: NavigationRouteRenderState(route: nil,
                                               progress: 0,
                                               elapsedTime: 0)
    )

    #expect(routes.transfer == fixture.controller.renderState)
}

@MainActor
private struct TransferOrbitControllerFixture {
    let viewportSize = CGSize(width: 390, height: 844)
    let source: FakeTransferSnapshotSource
    let provider: SnapshotProvider
    let cameraState: CameraState
    let cameraCoordinator: CameraCoordinator
    let controller: TransferOrbitController

    init(latestSnapshot: PreparedRenderSnapshot? = .transferOrbitControllerTestSnapshot) {
        let viewportSize = self.viewportSize
        source = FakeTransferSnapshotSource(latestSnapshot: latestSnapshot)
        cameraState = CameraState()
        provider = SnapshotProvider(cameraState: cameraState,
                                    snapshotSource: source)
        cameraCoordinator = CameraCoordinator(cameraState: cameraState,
                                              snapshotProvider: provider)
        controller = TransferOrbitController(snapshotProvider: provider,
                                             cameraCoordinator: cameraCoordinator,
                                             planets: testPlanets,
                                             viewportSize: { viewportSize })
    }
}

@MainActor
private final class FakeTransferSnapshotSource: PreparedRenderSnapshotProviding {
    var latestSnapshot: PreparedRenderSnapshot?

    init(latestSnapshot: PreparedRenderSnapshot?) {
        self.latestSnapshot = latestSnapshot
    }

    func requestPreparation(simulationTime: Float) {}
}

private extension PreparedRenderSnapshot {
    static var transferOrbitControllerTestSnapshot: PreparedRenderSnapshot {
        PreparedRenderSnapshot(frameID: 1,
                               simulationTime: 0,
                               planets: [
                                transferTestPacket(name: "Sun",
                                                   worldPosition: SIMD3<Float>(0, 0, 0),
                                                   framingRadius: 0.2),
                                transferTestPacket(name: "Earth",
                                                   worldPosition: SIMD3<Float>(1, 0, 0),
                                                   framingRadius: 0.05),
                                transferTestPacket(name: "Mars",
                                                   worldPosition: SIMD3<Float>(1.52, 0, 0),
                                                   framingRadius: 0.05)
                               ])
    }

    static func transferTestPacket(name: String,
                                   worldPosition: SIMD3<Float>,
                                   framingRadius: Float) -> PreparedPlanetRenderPacket {
        PreparedPlanetRenderPacket(planetName: name,
                                   baseModelMatrix: matrix_identity_float4x4,
                                   worldModelMatrix: matrix_identity_float4x4,
                                   normalizedScale: 1,
                                   framingRadius: framingRadius,
                                   surfaceRadius: framingRadius,
                                   worldPosition: worldPosition)
    }
}
