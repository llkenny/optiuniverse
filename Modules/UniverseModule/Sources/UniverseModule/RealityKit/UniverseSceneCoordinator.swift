import CoreGraphics
import RealityKit
import SwiftUI
import simd

@MainActor
// The coordinator intentionally centralizes atomic mutation of the canonical entity hierarchy.
// swiftlint:disable:next type_body_length
final class UniverseSceneCoordinator {
    static let realityKitCameraBasis = float4x4.makeRotationY(.pi)

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
    var animationPlaybackControllers: [String: [AnimationPlaybackController]] = [:]

    let snapshotProvider: SnapshotProvider
    let cameraCoordinator: CameraCoordinator
    private let objectInfoOverlayFramingState: ObjectInfoOverlayFramingState
    let navigationController: NavigationController
    let transferOrbitController: TransferOrbitController
    private let assetRepository: RealityAssetRepository
    private let occlusionCullingPolicy: CelestialOcclusionCullingPolicy
    let surfaceCoordinateDebugLogger = SurfaceCoordinateDebugLogger()
    private var simulationClock: UniverseSimulationClock
    private let simulationDidChange: (SimulationSnapshot) -> Void
    private var lastPublishedSimulationSnapshot: SimulationSnapshot?
    private var lastSimulationPublicationTime = -Double.infinity
    var bodyDescriptors: [String: CelestialAssetDescriptor] = [:]
    var proceduralSceneContent: RealityProceduralSceneContent?
    var installationRoot: Entity?
    var immersiveFocusState = ImmersiveFocusState()
    var immersiveTransferOverviewState = ImmersiveTransferOverviewState()
    private(set) var activeInstallationID: UUID?
    private var updateSubscription: EventSubscription?
    private(set) var viewportSize: CGSize = .zero
    private(set) var latestFrameState: UniverseFrameState?
    var immersiveFocusTransform: float4x4?
    var immersiveTransferOverviewTransform: float4x4?
    private(set) var updateCount: UInt64 = 0
    private(set) var isPresentationActive = true
    private var discardNextFrameDelta = false

    enum PreparationError: Error, Equatable {
        case missingBody(String)
    }

    init(planets: [Planet],
         snapshotProvider: SnapshotProvider,
         cameraCoordinator: CameraCoordinator,
         objectInfoOverlayFramingState: ObjectInfoOverlayFramingState,
         navigationController: NavigationController,
         transferOrbitController: TransferOrbitController,
         assetRepository: RealityAssetRepository,
         occlusionCullingPolicy: CelestialOcclusionCullingPolicy = .current,
         now: @escaping () -> Date = Date.init,
         simulationDidChange: @escaping (SimulationSnapshot) -> Void = { _ in }) {
        simulationClock = UniverseSimulationClock(now: now)
        self.simulationDidChange = simulationDidChange
        self.snapshotProvider = snapshotProvider
        self.cameraCoordinator = cameraCoordinator
        self.objectInfoOverlayFramingState = objectInfoOverlayFramingState
        self.navigationController = navigationController
        self.transferOrbitController = transferOrbitController
        self.assetRepository = assetRepository
        self.occlusionCullingPolicy = occlusionCullingPolicy
        buildHierarchy(planets: planets)
    }

    /// Restore an atomic current-date body snapshot before route/camera handoff callbacks run.
    func synchronizeLiveScene() {
        simulationClock.synchronizeLive()
        if snapshotProvider.hasPresentationMetrics {
            snapshotProvider.requestPreparation(simulationTime: simulationClock.currentTime,
                                                presentationTime: Float(simulationClock.presentationTime))
        }
        publishSimulationTime(force: true)
    }

    /// Capture liftoff orientation before constructing any Earth-relative mission geometry.
    func prepareMissionScene(_ replay: MissionReplay) {
        simulationClock.prepareMission(replay)
        snapshotProvider.requestPreparation(simulationTime: simulationClock.currentTime,
                                            presentationTime: Float(simulationClock.presentationTime))
        publishSimulationTime(force: true)
    }

    private func publishSimulationTime(force: Bool = false) {
        let date = SimulationTime.date(forTDBSeconds: simulationClock.currentTime)
        let snapshot = SimulationSnapshot(dateUTC: date,
                                          mode: simulationClock.mode, error: snapshotProvider.preparationError)
        let modeOrErrorChanged = lastPublishedSimulationSnapshot?.mode != snapshot.mode ||
            lastPublishedSimulationSnapshot?.error != snapshot.error
        guard force || modeOrErrorChanged
                || simulationClock.presentationTime - lastSimulationPublicationTime >= 1 else {
            return
        }
        lastSimulationPublicationTime = simulationClock.presentationTime
        lastPublishedSimulationSnapshot = snapshot
        simulationDidChange(snapshot)
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
        if isActive && !isPresentationActive { discardNextFrameDelta = true }
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

        let isResuming = discardNextFrameDelta
        let activeDelta = isResuming ? 0 : deltaTime
        discardNextFrameDelta = false
        let replay = navigationController.activeMissionReplay
        let previousMissionTime = simulationClock.missionElapsedTime
        let delta = simulationClock.advance(by: activeDelta,
                                            transfer: navigationController.activeTransfer,
                                            mission: replay)
        snapshotProvider.requestPreparation(simulationTime: simulationClock.currentTime,
                                            presentationTime: Float(simulationClock.presentationTime))
        let reachedMissionEnd = replay.map {
            previousMissionTime < $0.timeline.duration && simulationClock.missionElapsedTime >= $0.timeline.duration
        } ?? false
        publishSimulationTime(force: isResuming || reachedMissionEnd)
        guard snapshotProvider.preparationError == nil else {
            handleEphemerisFailure()
            return
        }
        transferOrbitController.update(snapshot: snapshotProvider.latestSnapshot, delta: delta)
        navigationController.update(snapshot: snapshotProvider.latestSnapshot, delta: delta,
                                    missionElapsedTime: simulationClock.mode == .missionReplay
                                        ? simulationClock.missionElapsedTime : nil)
        updateCameraAndScene(delta: delta)
    }

    private func updateCameraAndScene(delta: Float) {
        // A pending start can fail preflight and restore Live synchronously during navigation update.
        let snapshot = snapshotProvider.latestSnapshot
        let modeState = makeCameraFrameModeState()
        cameraCoordinator.updateFrameCamera(snapshot: snapshot,
                                            delta: delta,
                                            viewportSize: viewportSize,
                                            modeState: modeState)
        let overlayAdjustment = objectInfoOverlayFramingState.advance(delta: delta)
        let projection = makeCameraProjection(snapshot: snapshot,
                                              overlayAdjustment: overlayAdjustment,
                                              modeState: modeState)
        let cameraSnapshot = makeCameraSnapshot(snapshot: snapshot,
                                                projection: projection,
                                                modeState: modeState)
        logSurfaceCoordinateDebug(snapshot: snapshot,
                                  cameraSnapshot: cameraSnapshot,
                                  modeState: modeState)
        let frameState = UniverseFrameState(
            simulationTime: snapshot?.simulationTime ?? simulationClock.currentTime,
            presentationTime: Float(simulationClock.presentationTime),
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
            occlusionCullingPolicy.apply(to: bodyRoot, bodyName: planet.name)
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
        transferOrbitRoot.addChild(proceduralSceneContent.transferArrivalMarker)
        navigationRouteRoot.addChild(proceduralSceneContent.navigationPath.entity)
        navigationRouteRoot.addChild(navigationMarkerRoot)
        navigationMarkerRoot.addChild(proceduralSceneContent.navigationMarker)
        navigationMarkerRoot.addChild(proceduralSceneContent.starshipMission.root)
        navigationMarkerRoot.addChild(proceduralSceneContent.crew13Mission.root)
        navigationMarkerRoot.addChild(proceduralSceneContent.voyagerMission.root)
        self.proceduralSceneContent = proceduralSceneContent
    }

}
