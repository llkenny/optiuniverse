import CoreGraphics
import RealityKit
import SwiftUI
import simd

@MainActor
final class UniverseSceneCoordinator {
    struct BodyEntities {
        let bodyRoot: Entity
        let orbitTransform: Entity
        let rotationTransform: Entity
        let visualRoot: Entity
    }

    let universeRoot = Entity()
    let environmentRoot = Entity()
    let starFieldRoot = Entity()
    let celestialSystemRoot = Entity()
    let transferOrbitRoot = Entity()
    let navigationRouteRoot = Entity()
    let navigationMarkerRoot = Entity()
    let virtualCamera = Entity()
    private(set) var bodyEntities: [String: BodyEntities] = [:]

    private let snapshotProvider: SnapshotProvider
    private let cameraCoordinator: CameraCoordinator
    private let objectInfoOverlayFramingState: ObjectInfoOverlayFramingState
    private let navigationController: NavigationController
    private let transferOrbitController: TransferOrbitController
    private let assetRepository: RealityAssetRepository
    private let surfaceCoordinateDebugLogger = SurfaceCoordinateDebugLogger()
    private var simulationClock = UniverseSimulationClock()
    private var updateSubscription: EventSubscription?
    private(set) var viewportSize: CGSize = .zero
    private(set) var latestFrameState: UniverseFrameState?
    private(set) var updateCount: UInt64 = 0

    init(planets: [Planet],
         snapshotProvider: SnapshotProvider,
         cameraCoordinator: CameraCoordinator,
         objectInfoOverlayFramingState: ObjectInfoOverlayFramingState,
         navigationController: NavigationController,
         transferOrbitController: TransferOrbitController,
         assetRepository: RealityAssetRepository) {
        self.snapshotProvider = snapshotProvider
        self.cameraCoordinator = cameraCoordinator
        self.objectInfoOverlayFramingState = objectInfoOverlayFramingState
        self.navigationController = navigationController
        self.transferOrbitController = transferOrbitController
        self.assetRepository = assetRepository
        buildHierarchy(planets: planets)
    }

    func install(in content: inout RealityViewCameraContent) {
        updateSubscription?.cancel()
        content.entities.removeAll()
        content.add(universeRoot)
        content.camera = .virtual
        content.cameraTarget = virtualCamera
        updateSubscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            MainActor.assumeIsolated {
                self?.update(deltaTime: event.deltaTime)
            }
        }
    }

    func setViewportSize(_ size: CGSize) {
        guard size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0 else {
            return
        }
        viewportSize = size
    }

    func update(deltaTime: TimeInterval) {
        guard viewportSize.width > 0, viewportSize.height > 0 else { return }

        let delta = simulationClock.advance(by: deltaTime)
        snapshotProvider.requestPreparation(simulationTime: simulationClock.currentTime)
        let snapshot = snapshotProvider.latestSnapshot

        transferOrbitController.update(snapshot: snapshot, delta: delta)
        navigationController.update(snapshot: snapshot, delta: delta)
        let modeState = makeCameraFrameModeState()
        cameraCoordinator.updateFrameCamera(snapshot: snapshot,
                                            delta: delta,
                                            viewportSize: viewportSize,
                                            modeState: modeState)
        let overlayAdjustment = objectInfoOverlayFramingState.advance(delta: delta)
        let projection = makeCameraProjection(snapshot: snapshot,
                                              overlayAdjustment: overlayAdjustment)
        let cameraSnapshot = makeCameraSnapshot(snapshot: snapshot,
                                                projection: projection,
                                                modeState: modeState)
        logSurfaceCoordinateDebug(snapshot: snapshot,
                                  cameraSnapshot: cameraSnapshot,
                                  modeState: modeState)
        let frameState = UniverseFrameState(
            simulationTime: simulationClock.currentTime,
            cameraSnapshot: cameraSnapshot,
            snapshot: snapshot,
            routes: SceneRouteRenderState(transfer: transferOrbitController.renderState,
                                          navigation: navigationController.routeRenderState)
        )

        apply(frameState: frameState)
        latestFrameState = frameState
        updateCount += 1
    }

    func dismantle() {
        updateSubscription?.cancel()
        updateSubscription = nil
        assetRepository.cancelPendingLoads()
        universeRoot.removeFromParent()
        latestFrameState = nil
    }

    private func buildHierarchy(planets: [Planet]) {
        universeRoot.name = "UniverseRoot"
        environmentRoot.name = "Environment"
        starFieldRoot.name = "StarField"
        celestialSystemRoot.name = "CelestialSystemRoot"
        transferOrbitRoot.name = "TransferOrbit"
        navigationRouteRoot.name = "NavigationRoute"
        navigationMarkerRoot.name = "NavigationMarker"
        virtualCamera.name = "VirtualCamera"

        universeRoot.addChild(environmentRoot)
        universeRoot.addChild(starFieldRoot)
        universeRoot.addChild(celestialSystemRoot)
        universeRoot.addChild(transferOrbitRoot)
        universeRoot.addChild(navigationRouteRoot)
        navigationRouteRoot.addChild(navigationMarkerRoot)
        universeRoot.addChild(virtualCamera)

        for planet in planets {
            let bodyRoot = Entity()
            bodyRoot.name = planet.name
            let orbitTransform = Entity()
            orbitTransform.name = "\(planet.name).BodyOrbitTransform"
            let rotationTransform = Entity()
            rotationTransform.name = "\(planet.name).BodyRotationTransform"
            let visualRoot = Entity()
            visualRoot.name = "\(planet.name).BodyVisualRoot"
            bodyRoot.addChild(orbitTransform)
            orbitTransform.addChild(rotationTransform)
            rotationTransform.addChild(visualRoot)
            celestialSystemRoot.addChild(bodyRoot)
            bodyEntities[planet.name] = BodyEntities(bodyRoot: bodyRoot,
                                                     orbitTransform: orbitTransform,
                                                     rotationTransform: rotationTransform,
                                                     visualRoot: visualRoot)
        }
    }

    private func makeCameraFrameModeState() -> CameraFrameModeState {
        CameraFrameModeState(
            navigationControlsCamera: navigationController.controlsCamera,
            navigation: navigationController.cameraSnapshotDependency,
            transferPreviewActive: transferOrbitController.isTransferPreviewActive,
            transfer: transferOrbitController.cameraSnapshotDependency
        )
    }

    private func makeCameraProjection(
        snapshot: PreparedRenderSnapshot?,
        overlayAdjustment: ObjectInfoOverlayFramingState.ProjectionAdjustment
    ) -> CameraProjectionParameters {
        let baseProjection = CameraProjectionParameters(
            nearPlane: CameraFit.defaultNearPlane,
            farPlane: CameraFit.defaultFarPlane,
            verticalFieldOfView: overlayAdjustment.verticalFieldOfView,
            verticalCenterOffset: overlayAdjustment.verticalCenterOffset
        )
        let followProjection = cameraCoordinator.followProjectionParameters(snapshot: snapshot,
                                                                            baseProjection: baseProjection)
        let transferProjection = transferOrbitController.projectionParameters(snapshot: snapshot,
                                                                               baseProjection: followProjection)
        return navigationController.projectionParameters(snapshot: snapshot,
                                                         baseProjection: transferProjection)
    }

    private func makeCameraSnapshot(
        snapshot: PreparedRenderSnapshot?,
        projection: CameraProjectionParameters,
        modeState: CameraFrameModeState
    ) -> SnapshotProvider.CameraSnapshot {
        let dependencies = cameraCoordinator.makeSnapshotDependencies(
            snapshot: snapshot,
            viewportSize: viewportSize,
            projection: projection,
            modeState: modeState
        )
        return snapshotProvider.makeCameraSnapshot(dependencies: dependencies)
    }

    func apply(frameState: UniverseFrameState) {
        let cameraSnapshot = frameState.cameraSnapshot
        virtualCamera.setTransformMatrix(simd_inverse(cameraSnapshot.renderViewMatrix),
                                         relativeTo: universeRoot)
        virtualCamera.components.set(
            ProjectiveTransformCameraComponent(projectionMatrix: cameraSnapshot.projectionMatrix)
        )

        guard let snapshot = frameState.snapshot else { return }
        for packet in snapshot.planets {
            guard let entities = bodyEntities[packet.planetName] else { continue }
            entities.bodyRoot.position = packet.worldPosition - cameraSnapshot.sceneOrigin

            var localModelMatrix = packet.baseModelMatrix
            localModelMatrix.columns.3 = SIMD4<Float>(0, 0, 0, 1)
            entities.rotationTransform.transform = Transform(matrix: localModelMatrix)
        }
    }

    private func logSurfaceCoordinateDebug(snapshot: PreparedRenderSnapshot?,
                                           cameraSnapshot: SnapshotProvider.CameraSnapshot,
                                           modeState: CameraFrameModeState) {
        guard let snapshot,
              let bodyName = surfaceCoordinateDebugTargetName(cameraSnapshot: cameraSnapshot,
                                                              modeState: modeState),
              let planet = snapshot.planet(named: bodyName) else {
            return
        }

        surfaceCoordinateDebugLogger.logIfNeeded(bodyName: bodyName,
                                                 planet: planet,
                                                 snapshot: snapshot,
                                                 cameraSnapshot: cameraSnapshot)
    }

    private func surfaceCoordinateDebugTargetName(
        cameraSnapshot: SnapshotProvider.CameraSnapshot,
        modeState: CameraFrameModeState
    ) -> String? {
        if modeState.navigationControlsCamera,
           let destinationName = modeState.navigation?.destinationName {
            return destinationName
        }
        return cameraSnapshot.dependencies.followedObject?.planetName
    }
}
