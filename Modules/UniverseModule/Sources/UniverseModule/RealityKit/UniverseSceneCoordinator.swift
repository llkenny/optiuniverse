import CoreGraphics
import RealityKit
import SwiftUI
import simd

@MainActor
// The coordinator intentionally centralizes atomic mutation of the canonical entity hierarchy.
// swiftlint:disable:next type_body_length
final class UniverseSceneCoordinator {
    private static let realityKitCameraBasis = float4x4.makeRotationY(.pi)

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
    let sunLight = Entity()
    private(set) var bodyEntities: [String: BodyEntities] = [:]
    private(set) var realityKitOwnedBodyNames: Set<String> = []
    private(set) var isProceduralSceneContentPrepared = false

    private let snapshotProvider: SnapshotProvider
    private let cameraCoordinator: CameraCoordinator
    private let objectInfoOverlayFramingState: ObjectInfoOverlayFramingState
    private let navigationController: NavigationController
    private let transferOrbitController: TransferOrbitController
    private let assetRepository: RealityAssetRepository
    private let surfaceCoordinateDebugLogger = SurfaceCoordinateDebugLogger()
    private var simulationClock = UniverseSimulationClock()
    private var bodyDescriptors: [String: CelestialAssetDescriptor] = [:]
    private var proceduralSceneContent: RealityProceduralSceneContent?
    private var installationRoot: Entity?
    private(set) var activeInstallationID: UUID?
    private var updateSubscription: EventSubscription?
    private(set) var viewportSize: CGSize = .zero
    private(set) var latestFrameState: UniverseFrameState?
    private(set) var updateCount: UInt64 = 0
    private(set) var isPresentationActive = true

    enum PreparationError: Error, Equatable {
        case missingBody(String)
    }

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

    func install(in content: inout RealityViewCameraContent,
                 installationID: UUID) {
        registerInstallation(installationID)
        updateSubscription?.cancel()
        updateSubscription = nil
        attachSceneIfNeeded(to: &content, installationID: installationID)
        subscribeToUpdates(in: content)
    }

    func restoreInstallationIfNeeded(in content: inout RealityViewCameraContent,
                                     installationID: UUID) {
        if activeInstallationID != installationID {
            install(in: &content, installationID: installationID)
            return
        }
        attachSceneIfNeeded(to: &content, installationID: installationID)
        guard updateSubscription == nil else { return }
        subscribeToUpdates(in: content)
    }

    private func attachSceneIfNeeded(to content: inout RealityViewCameraContent,
                                     installationID: UUID) {
        guard activeInstallationID == installationID else { return }

        if let installationRoot,
           content.entities.contains(where: { $0 === installationRoot }) {
            if universeRoot.parent !== installationRoot {
                installationRoot.addChild(universeRoot)
            }
        } else {
            universeRoot.removeFromParent()
            let installationRoot = Entity()
            installationRoot.name = "RealityViewInstallationRoot"
            installationRoot.addChild(universeRoot)
            content.add(installationRoot)
            self.installationRoot = installationRoot
        }
        content.camera = .virtual
        content.cameraTarget = virtualCamera
    }

    private func subscribeToUpdates(in content: RealityViewCameraContent) {
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

    func setPresentationActive(_ isActive: Bool) {
        isPresentationActive = isActive
    }

    func prepareCelestialBodies(from manifest: CelestialAssetManifest) async throws {
        let requestedBodyNames = Set(manifest.assets.map(\.displayName))
        guard requestedBodyNames != realityKitOwnedBodyNames || !isProceduralSceneContentPrepared else {
            return
        }

        var preparedAssets: [(CelestialAssetDescriptor, Entity)] = []
        preparedAssets.reserveCapacity(manifest.assets.count)

        for descriptor in manifest.assets {
            try Task.checkCancellation()
            guard bodyEntities[descriptor.displayName] != nil else {
                throw PreparationError.missingBody(descriptor.displayName)
            }
            let entity = try await assetRepository.entity(for: descriptor)
            preparedAssets.append((descriptor, entity))
        }

        let preparedProceduralSceneContent = try await RealityProceduralSceneContent.prepare()

        try Task.checkCancellation()
        for (descriptor, assetRoot) in preparedAssets {
            guard let entities = bodyEntities[descriptor.displayName] else {
                throw PreparationError.missingBody(descriptor.displayName)
            }
            entities.visualRoot.children.removeAll()
            entities.visualRoot.transform = descriptor.visualCorrectionTransform
            entities.visualRoot.addChild(assetRoot)
        }
        install(proceduralSceneContent: preparedProceduralSceneContent)
        bodyDescriptors = Dictionary(uniqueKeysWithValues: manifest.assets.map {
            ($0.displayName, $0)
        })
        realityKitOwnedBodyNames = requestedBodyNames
        isProceduralSceneContentPrepared = true
    }

    func update(deltaTime: TimeInterval) {
        guard isPresentationActive,
              viewportSize.width > 0,
              viewportSize.height > 0 else {
            return
        }

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

    func registerInstallation(_ installationID: UUID) {
        activeInstallationID = installationID
    }

    func dismantle(installationID: UUID) {
        guard activeInstallationID == installationID else { return }
        dismantle()
    }

    func dismantle() {
        updateSubscription?.cancel()
        updateSubscription = nil
        assetRepository.cancelPendingLoads()
        universeRoot.removeFromParent()
        installationRoot = nil
        activeInstallationID = nil
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
        sunLight.name = CelestialLightingConfiguration.SunPointLight.entityName
        sunLight.components.set(CelestialLightingConfiguration.SunPointLight.component)

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
            if planet.name == "Sun" {
                bodyRoot.addChild(sunLight)
            }
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
        snapshot: UniverseSceneSnapshot?,
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
        snapshot: UniverseSceneSnapshot?,
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
        let cameraTransform = simd_inverse(cameraSnapshot.renderViewMatrix)
            * Self.realityKitCameraBasis
        let projectionMatrix = Self.makeRealityKitProjection(from: cameraSnapshot)
        virtualCamera.setTransformMatrix(cameraTransform,
                                         relativeTo: universeRoot)
        virtualCamera.components.set(
            ProjectiveTransformCameraComponent(projectionMatrix: projectionMatrix)
        )

        proceduralSceneContent?.update(frameState: frameState)

        guard let snapshot = frameState.snapshot else { return }
        for packet in snapshot.planets {
            guard let entities = bodyEntities[packet.planetName] else { continue }
            entities.bodyRoot.position = packet.worldPosition - cameraSnapshot.sceneOrigin

            var localModelMatrix = packet.baseModelMatrix
            localModelMatrix.columns.3 = SIMD4<Float>(0, 0, 0, 1)
            entities.rotationTransform.transform = Transform(matrix: localModelMatrix)
            if bodyDescriptors[packet.planetName]?.usesSnapshotScale == true {
                entities.visualRoot.scale = SIMD3<Float>(repeating: packet.normalizedScale)
            }
        }
    }

    private func install(proceduralSceneContent: RealityProceduralSceneContent) {
        environmentRoot.children.removeAll()
        starFieldRoot.children.removeAll()
        transferOrbitRoot.children.removeAll()
        navigationRouteRoot.children.removeAll()
        navigationMarkerRoot.children.removeAll()

        environmentRoot.addChild(proceduralSceneContent.environmentEntity)
        starFieldRoot.addChild(proceduralSceneContent.starField.entity)
        transferOrbitRoot.addChild(proceduralSceneContent.transferEarthOrbit.entity)
        transferOrbitRoot.addChild(proceduralSceneContent.transferDestinationOrbit.entity)
        transferOrbitRoot.addChild(proceduralSceneContent.transferPath.entity)
        navigationRouteRoot.addChild(proceduralSceneContent.navigationPath.entity)
        navigationRouteRoot.addChild(navigationMarkerRoot)
        navigationMarkerRoot.addChild(proceduralSceneContent.navigationMarker)
        self.proceduralSceneContent = proceduralSceneContent
    }

    static func makeRealityKitProjection(
        from cameraSnapshot: SnapshotProvider.CameraSnapshot
    ) -> float4x4 {
        let legacyProjection = cameraSnapshot.projectionMatrix
        let near = cameraSnapshot.dependencies.projection.nearPlane
        let far = cameraSnapshot.dependencies.projection.farPlane
        let reverseDepthScale = near / (far - near)
        let reverseDepthTranslation = far * reverseDepthScale

        // ProjectiveTransformCameraComponent requires reverse depth. The camera basis
        // converts the legacy +Z camera into RealityKit's -Z camera, and the projection
        // keeps the app's intended screen-space left/right and up/down mapping.
        return float4x4(
            [legacyProjection[0][0], 0, 0, 0],
            [0, legacyProjection[1][1], 0, 0],
            [0, -legacyProjection[2][1], reverseDepthScale, -1],
            [0, 0, reverseDepthTranslation, 0]
        )
    }

    private func logSurfaceCoordinateDebug(snapshot: UniverseSceneSnapshot?,
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

private extension CelestialAssetDescriptor {
    var visualCorrectionTransform: Transform {
        let renderScale = modelToUniverseScale * (renderRadius / referenceRadius)
        return Transform(
            scale: SIMD3<Float>(repeating: renderScale),
            rotation: simd_quatf(
                ix: orientationCorrection.xAxis,
                iy: orientationCorrection.yAxis,
                iz: orientationCorrection.zAxis,
                r: orientationCorrection.real
            ),
            translation: SIMD3<Float>(
                pivotCorrection.xAxis,
                pivotCorrection.yAxis,
                pivotCorrection.zAxis
            )
        )
    }
}
