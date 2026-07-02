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
    private(set) var animationPlaybackControllers: [String: [AnimationPlaybackController]] = [:]

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
    private var immersiveFocusState = ImmersiveFocusState()
    private var immersiveTransferOverviewState = ImmersiveTransferOverviewState()
    private(set) var activeInstallationID: UUID?
    private var updateSubscription: EventSubscription?
    private(set) var viewportSize: CGSize = .zero
    private(set) var latestFrameState: UniverseFrameState?
    private(set) var immersiveFocusTransform: float4x4?
    private(set) var immersiveTransferOverviewTransform: float4x4?
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

    #if os(visionOS)
    func install(in content: inout RealityViewContent,
                 installationID: UUID) {
        registerInstallation(installationID)
        updateSubscription?.cancel()
        updateSubscription = nil
        attachSceneIfNeeded(to: &content, installationID: installationID)
        resumeConfiguredAnimationsIfNeeded()
        subscribeToUpdates(in: content)
    }

    func restoreInstallationIfNeeded(in content: inout RealityViewContent,
                                     installationID: UUID) {
        if activeInstallationID != installationID {
            install(in: &content, installationID: installationID)
            return
        }
        attachSceneIfNeeded(to: &content, installationID: installationID)
        resumeConfiguredAnimationsIfNeeded()
        guard updateSubscription == nil else { return }
        subscribeToUpdates(in: content)
    }
    #else
    func install(in content: inout RealityViewCameraContent,
                 installationID: UUID) {
        registerInstallation(installationID)
        updateSubscription?.cancel()
        updateSubscription = nil
        attachSceneIfNeeded(to: &content, installationID: installationID)
        content.camera = .virtual
        content.cameraTarget = virtualCamera
        resumeConfiguredAnimationsIfNeeded()
        subscribeToUpdates(in: content)
    }

    func restoreInstallationIfNeeded(in content: inout RealityViewCameraContent,
                                     installationID: UUID) {
        if activeInstallationID != installationID {
            install(in: &content, installationID: installationID)
            return
        }
        attachSceneIfNeeded(to: &content, installationID: installationID)
        content.camera = .virtual
        content.cameraTarget = virtualCamera
        resumeConfiguredAnimationsIfNeeded()
        guard updateSubscription == nil else { return }
        subscribeToUpdates(in: content)
    }
    #endif

    private func attachSceneIfNeeded<Content: RealityViewContentProtocol>(
        to content: inout Content,
        installationID: UUID
    ) {
        guard activeInstallationID == installationID else { return }

        if let installationRoot,
           content.entities.contains(where: { $0 === installationRoot }) {
            if universeRoot.parent !== installationRoot {
                installationRoot.addChild(universeRoot)
            }
            applyImmersiveFocusIfPossible(frameState: latestFrameState)
        } else {
            universeRoot.removeFromParent()
            let installationRoot = Entity()
            installationRoot.name = "RealityViewInstallationRoot"
            installationRoot.addChild(universeRoot)
            content.add(installationRoot)
            self.installationRoot = installationRoot
            applyImmersiveFocusIfPossible(frameState: latestFrameState)
        }
    }

    private func subscribeToUpdates<Content: RealityViewContentProtocol>(in content: Content) {
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

    var hasImmersiveFocus: Bool {
        immersiveFocusState.hasFocus && !hasImmersiveTransferOverview
    }

    private var hasImmersiveTransferOverview: Bool {
        transferOrbitController.isTransferPreviewActive ||
        immersiveTransferOverviewState.hasPersistedTransform
    }

    func beginImmersiveTransferOverview() {
        immersiveTransferOverviewState.begin()
        applyImmersiveFocusIfPossible(frameState: latestFrameState)
    }

    func clearImmersiveTransferOverview() {
        immersiveTransferOverviewState.clear()
        immersiveTransferOverviewTransform = nil
        applyImmersiveFocusIfPossible(frameState: latestFrameState)
    }

    func setImmersiveFocus(bodyName: String) {
        immersiveFocusState.focus(on: bodyName)
        applyImmersiveFocusIfPossible(frameState: latestFrameState)
    }

    func clearImmersiveFocus() {
        immersiveFocusState.clear()
        immersiveTransferOverviewState.clear()
        immersiveFocusTransform = nil
        immersiveTransferOverviewTransform = nil
        applyImmersiveFocusIfPossible(frameState: latestFrameState)
    }

    func adjustImmersiveFocusRotation(translation: CGSize) -> Bool {
        guard !hasImmersiveTransferOverview else { return false }
        guard immersiveFocusState.rotate(translation: translation) else { return false }
        applyImmersiveFocusIfPossible(frameState: latestFrameState)
        return true
    }

    func adjustImmersiveFocusScale(by scale: Float) -> Bool {
        guard !hasImmersiveTransferOverview else { return false }
        guard immersiveFocusState.scale(by: scale) else { return false }
        applyImmersiveFocusIfPossible(frameState: latestFrameState)
        return true
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
            stopAnimations(for: descriptor.displayName)
            entities.visualRoot.children.removeAll()
            entities.visualRoot.transform = descriptor.visualCorrectionTransform
            entities.visualRoot.addChild(assetRoot)
            playConfiguredAnimations(for: descriptor, on: assetRoot)
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
        stopAllAnimations()
        clearImmersiveFocus()
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
                orbitTransform.addChild(sunLight)
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
        return transferOrbitController.projectionParameters(snapshot: snapshot,
                                                            baseProjection: followProjection)
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
            entities.bodyRoot.position = -cameraSnapshot.sceneOrigin
            entities.orbitTransform.transform = Transform(matrix: packet.orbitTransformMatrix)
            entities.rotationTransform.transform = Transform(matrix: packet.visualRotationMatrix)
            if bodyDescriptors[packet.planetName]?.usesSnapshotScale == true {
                entities.visualRoot.scale = SIMD3<Float>(repeating: packet.normalizedScale)
            }
        }
        applyImmersiveFocusIfPossible(frameState: frameState)
    }

    private func applyImmersiveFocusIfPossible(frameState: UniverseFrameState?) {
        if transferOrbitController.isTransferPreviewActive,
           let frameState,
           let transform = immersiveTransferOverviewState.persist(
                cameraPose: cameraCoordinator.currentCameraPose,
                targetAfterSceneOrigin: cameraCoordinator.currentCameraPose.target
                    - frameState.cameraSnapshot.sceneOrigin
           ) {
            immersiveTransferOverviewTransform = transform
            installationRoot?.transform = Transform(matrix: transform)
            return
        }

        if let transform = immersiveTransferOverviewState.persistedTransform {
            immersiveTransferOverviewTransform = transform
            installationRoot?.transform = Transform(matrix: transform)
            return
        }

        immersiveTransferOverviewTransform = nil
        guard immersiveFocusState.hasFocus else {
            immersiveFocusTransform = nil
            installationRoot?.transform = .identity
            return
        }
        guard let frameState,
              let snapshot = frameState.snapshot,
              let bodyName = immersiveFocusState.bodyName,
              let bodySnapshot = snapshot.planet(named: bodyName),
              let transform = immersiveFocusState.transform(
                  selectedBodyPositionAfterSceneOrigin: bodySnapshot.worldPosition
                    - frameState.cameraSnapshot.sceneOrigin,
                  framingRadius: bodySnapshot.framingRadius
              ) else {
            return
        }

        immersiveFocusTransform = transform
        installationRoot?.transform = Transform(matrix: transform)
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

    private func playConfiguredAnimations(for descriptor: CelestialAssetDescriptor,
                                          on assetRoot: Entity) {
        guard !descriptor.animations.isEmpty else { return }
        let availableAnimations = assetRoot.availableAnimations.reduce(
            into: [String: AnimationResource]()
        ) { animationsByName, animation in
            animationsByName[animation.name] = animationsByName[animation.name] ?? animation
        }
        var controllers: [AnimationPlaybackController] = []
        controllers.reserveCapacity(descriptor.animations.count)
        for configuredAnimation in descriptor.animations {
            let animationOwnerAndResource = availableAnimations[configuredAnimation.name].map {
                (assetRoot, $0)
            } ?? animationResource(named: configuredAnimation.name, in: assetRoot)
            guard let (animationOwner, animation) = animationOwnerAndResource else { continue }
            let playbackAnimation = configuredAnimation.repeats ? animation.repeat() : animation
            controllers.append(animationOwner.playAnimation(playbackAnimation))
        }
        if !controllers.isEmpty {
            animationPlaybackControllers[descriptor.displayName] = controllers
        }
    }

    func resumeConfiguredAnimationsIfNeeded() {
        for (bodyName, descriptor) in bodyDescriptors where !descriptor.animations.isEmpty {
            guard animationPlaybackControllers[bodyName]?.isEmpty != false,
                  let assetRoot = bodyEntities[bodyName]?.visualRoot.children.first else {
                continue
            }
            playConfiguredAnimations(for: descriptor, on: assetRoot)
        }
    }

    private func stopAnimations(for bodyName: String) {
        animationPlaybackControllers[bodyName]?.forEach { $0.stop() }
        animationPlaybackControllers[bodyName] = nil
    }

    private func stopAllAnimations() {
        animationPlaybackControllers.values.flatMap { $0 }.forEach { $0.stop() }
        animationPlaybackControllers.removeAll()
    }

    private func animationResource(named name: String,
                                   in entity: Entity) -> (Entity, AnimationResource)? {
        if let animationLibrary = entity.components[AnimationLibraryComponent.self] {
            if let animation = animationLibrary.animations[name] {
                return (entity, animation)
            }
            if let animation = animationLibrary.animations.first(where: {
                Self.animationKey($0.key, matches: name)
            })?.value {
                return (entity, animation)
            }
        }
        for child in entity.children {
            if let animation = animationResource(named: name, in: child) {
                return animation
            }
        }
        return nil
    }

    private static func animationKey(_ key: String, matches configuredName: String) -> Bool {
        key.split(separator: "/").last.map(String.init) == configuredName
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
