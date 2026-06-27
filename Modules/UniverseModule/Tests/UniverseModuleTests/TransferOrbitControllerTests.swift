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
@Test func transferOrbitControllerOverviewUsesSunCenteredTiltedFraming() throws {
    let fixture = TransferOrbitControllerFixture()

    fixture.controller.showTransferOrbit(to: "Mars")
    fixture.controller.update(snapshot: fixture.source.latestSnapshot,
                              delta: 2)

    #expect(fixture.cameraState.cameraTarget == .zero)
    #expect(fixture.cameraState.cameraDistance == CameraFit.distanceToFitWidth(
        radius: 1.52,
        currentDistance: 3,
        viewportSize: fixture.viewportSize
    ))

    let cameraOffset = fixture.cameraState.cameraOrientation.act(SIMD3<Float>(0, 0, 1))
    #expect(cameraOffset.y > 0.65)
    #expect(cameraOffset.z > 0.65)
}

@MainActor
@Test func transferOrbitControllerImmediatelyFramesOuterSystemTransfers() throws {
    let farUranus = Planet(name: "Uranus",
                           meshName: "Uranus",
                           parentName: nil,
                           radius: 1,
                           distance: 2_867,
                           orbitSpeed: 0,
                           rotationSpeedKmSec: 0)
    let planets = testPlanets.filter { $0.name != "Uranus" } + [farUranus]
    let fixture = TransferOrbitControllerFixture(
        latestSnapshot: .outerTransferSnapshot(destinationName: "Uranus",
                                                destinationDistance: farUranus.distance),
        planets: planets
    )

    fixture.controller.showTransferOrbit(to: "Uranus")

    #expect(fixture.cameraState.cameraTarget == .zero)
    #expect(fixture.cameraState.cameraDistance > CameraState.defaultMaximumDistance)
    #expect(fixture.controller.cameraSnapshotDependency?.hasActiveTransition == false)
}

@MainActor
@Test func transferOverviewRetainsOuterPlanetFitDuringCameraRefresh() throws {
    for destination in ["Neptune", "Pluto"] {
        let fixture = TransferOrbitControllerFixture(
            latestSnapshot: .outerTransferSnapshot(destinationName: destination),
            planets: testPlanets
        )

        fixture.controller.showTransferOrbit(to: destination)
        fixture.controller.update(snapshot: fixture.source.latestSnapshot,
                                  delta: 2)

        let destinationRadius = try #require(testPlanets.first { $0.name == destination }?.distance)
        let expectedDistance = CameraFit.distanceToFitWidth(
            radius: destinationRadius,
            currentDistance: 3,
            viewportSize: fixture.viewportSize
        )
        let dependency = try #require(fixture.controller.cameraSnapshotDependency)
        #expect(dependency.maximumCameraDistance ?? 0 > expectedDistance)

        fixture.cameraCoordinator.updateFrameCamera(
            snapshot: fixture.source.latestSnapshot,
            delta: 0,
            viewportSize: fixture.viewportSize,
            modeState: CameraFrameModeState(navigationControlsCamera: false,
                                            navigation: nil,
                                            transferPreviewActive: true,
                                            transfer: dependency)
        )

        #expect(abs(fixture.cameraState.cameraDistance - expectedDistance) < 0.001)
    }
}

@MainActor
@Test func transferProjectionLeavesHeadroomForOuterOrbitGeometry() throws {
    let fixture = TransferOrbitControllerFixture(
        latestSnapshot: .outerTransferSnapshot(destinationName: "Uranus"),
        planets: testPlanets
    )
    fixture.controller.showTransferOrbit(to: "Uranus")
    fixture.controller.update(snapshot: fixture.source.latestSnapshot,
                              delta: 2)

    let projection = fixture.controller.projectionParameters(
        snapshot: fixture.source.latestSnapshot,
        baseProjection: CameraProjectionParameters(nearPlane: 0.1, farPlane: 1)
    )
    let uranusRadius = try #require(testPlanets.first { $0.name == "Uranus" }?.distance)
    let requiredFarPlane = fixture.cameraState.cameraDistance + uranusRadius * 2

    #expect(projection.farPlane >= requiredFarPlane)
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

    init(latestSnapshot: UniverseSceneSnapshot? = .transferOrbitControllerTestSnapshot,
         planets: [Planet] = testPlanets) {
        let viewportSize = self.viewportSize
        source = FakeTransferSnapshotSource(latestSnapshot: latestSnapshot)
        cameraState = CameraState()
        provider = SnapshotProvider(cameraState: cameraState,
                                    snapshotSource: source)
        cameraCoordinator = CameraCoordinator(cameraState: cameraState,
                                              snapshotProvider: provider)
        controller = TransferOrbitController(snapshotProvider: provider,
                                             cameraCoordinator: cameraCoordinator,
                                             planets: planets,
                                             viewportSize: { viewportSize })
    }
}

@MainActor
private final class FakeTransferSnapshotSource: UniverseSceneSnapshotProviding {
    var latestSnapshot: UniverseSceneSnapshot?

    init(latestSnapshot: UniverseSceneSnapshot?) {
        self.latestSnapshot = latestSnapshot
    }

    func requestPreparation(simulationTime: Float) {}
}

private extension UniverseSceneSnapshot {
    static var transferOrbitControllerTestSnapshot: UniverseSceneSnapshot {
        UniverseSceneSnapshot(frameID: 1,
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

    static func outerTransferSnapshot(destinationName: String,
                                      destinationDistance: Float? = nil) -> UniverseSceneSnapshot {
        let destinationDistance = destinationDistance
            ?? testPlanets.first { $0.name == destinationName }?.distance
            ?? 1
        return UniverseSceneSnapshot(
            frameID: 1,
            simulationTime: 0,
            planets: [
                transferTestPacket(name: "Sun",
                                   worldPosition: .zero,
                                   framingRadius: 0.2),
                transferTestPacket(name: "Earth",
                                   worldPosition: SIMD3<Float>(1, 0, 0),
                                   framingRadius: 0.05),
                transferTestPacket(name: destinationName,
                                   worldPosition: SIMD3<Float>(destinationDistance, 0, 0),
                                   framingRadius: 0.05)
            ]
        )
    }

    static func transferTestPacket(name: String,
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
