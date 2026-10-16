//
//  UniverseModuleResources.swift
//  UniverseModule
//
//  Created by Codex on 24.05.2026.
//

internal import BaseModule
import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
public final class UniverseModuleResources {
    let planets: [Planet]
    let sceneSnapshotPipeline: UniverseSceneSnapshotPipeline
    let cameraState: CameraState
    let cameraCoordinator: CameraCoordinator
    let snapshotProvider: SnapshotProvider
    let objectInfoOverlayFramingState: ObjectInfoOverlayFramingState
    let assetRepository: RealityAssetRepository
    private let celestialAssetManifestLoader: () throws -> CelestialAssetManifest
    public internal(set) var transferPreviewSnapshot: TransferPreviewSnapshot = .inactive
    public internal(set) var navigationSnapshot: NavigationRouteSnapshot = .idle
    public internal(set) var simulationSnapshot: SimulationSnapshot
    private let now: () -> Date
    @ObservationIgnored private(set) var transferOrbitController: TransferOrbitController!
    @ObservationIgnored private(set) var navigationController: NavigationController!
    @ObservationIgnored private(set) lazy var sceneCoordinator = UniverseSceneCoordinator(
        planets: planets,
        snapshotProvider: snapshotProvider,
        cameraCoordinator: cameraCoordinator,
        objectInfoOverlayFramingState: objectInfoOverlayFramingState,
        navigationController: navigationController,
        transferOrbitController: transferOrbitController,
        assetRepository: assetRepository,
        now: now,
        simulationDidChange: { [weak self] snapshot in self?.simulationSnapshot = snapshot }
    )
    @ObservationIgnored private(set) var viewportSize: CGSize = .zero
    @ObservationIgnored private var preparationTask: Task<Void, any Error>?
    @ObservationIgnored private var isPrepared = false
    @ObservationIgnored private var stateProviderLoader: (@Sendable () throws -> any CelestialStateProviding)?

    var isTrajectoryModeActive: Bool {
        transferOrbitController.isTransferPreviewActive ||
        navigationController.isNavigationActive
    }

    public var isImmersiveFocusActive: Bool {
        sceneCoordinator.hasImmersiveFocus
    }

    init(
        assetRepository: RealityAssetRepository = RealityAssetRepository(),
        stateProvider: (any CelestialStateProviding)? = nil,
        stateProviderLoader: @escaping @Sendable () throws -> any CelestialStateProviding = {
            try EphemerisArchive.bundled.get()
        },
        now: @escaping () -> Date = Date.init,
        celestialAssetManifestLoader: @escaping () throws -> CelestialAssetManifest = {
            try CelestialAssetManifestLoader.load()
        }
    ) {
        self.now = now
        simulationSnapshot = SimulationSnapshot(dateUTC: now())
        planets = (try? SolarSystemLoader.loadPlanets(from: "planets")) ?? []
        self.stateProviderLoader = stateProvider == nil ? stateProviderLoader : nil
        let provider = stateProvider ?? UnavailableCelestialStateProvider()
        sceneSnapshotPipeline = UniverseSceneSnapshotPipeline(planets: planets, stateProvider: provider)
        cameraState = CameraState()
        snapshotProvider = SnapshotProvider(cameraState: cameraState,
                                            snapshotSource: sceneSnapshotPipeline)
        cameraCoordinator = CameraCoordinator(cameraState: cameraState,
                                              snapshotProvider: snapshotProvider)
        objectInfoOverlayFramingState = ObjectInfoOverlayFramingState()
        self.assetRepository = assetRepository
        self.celestialAssetManifestLoader = celestialAssetManifestLoader
        transferOrbitController = TransferOrbitController(
            snapshotProvider: snapshotProvider,
            cameraCoordinator: cameraCoordinator,
            planets: planets,
            viewportSize: { [weak self] in
                self?.viewportSize ?? .zero
            }
        )
        transferOrbitController.snapshotDidChange = { [weak self] snapshot in
            self?.transferPreviewSnapshot = snapshot
        }
        navigationController = NavigationController(
            snapshotProvider: snapshotProvider,
            planets: planets
        )
        configureNavigationCallbacks()
    }

    private func configureNavigationCallbacks() {
        navigationController.navigationSnapshotDidChange = { [weak self] snapshot in
            self?.navigationSnapshot = snapshot
        }
        navigationController.synchronizeLiveScene = { [weak self] in self?.sceneCoordinator.synchronizeLiveScene() }
        navigationController.prepareMissionScene = { [weak self] replay in
            self?.sceneCoordinator.prepareMissionScene(replay)
        }
        navigationController.navigationDidComplete = { [weak self] name, mission in
            guard let self else { return }
            if mission == .crew13 {
                cameraCoordinator.followNavigationDestination(named: "Earth", viewportSize: viewportSize)
            } else if mission == .starshipFlight14 {
                // Surface close-ups finish away from the body's center. Animate back out
                // instead of adopting an Earth-centered pivot at the close-up distance.
                cameraCoordinator.followNavigationDestination(named: name, viewportSize: viewportSize)
            } else {
                cameraCoordinator.adoptNavigationDestination(named: name)
            }
        }
        transferOrbitController.followPlanet = { [weak self] name in
            guard let self else { return }
            cameraCoordinator.followNavigationDestination(named: name,
                                                          viewportSize: viewportSize)
        }
        transferOrbitController.transferPreviewDidBegin = { [weak self] in
            #if os(visionOS)
            self?.sceneCoordinator.beginImmersiveTransferOverview()
            #endif
        }
    }

    public func prepare() async throws {
        guard !planets.isEmpty else { throw UniverseModulePreparationError.invalidOrbitalData }
        guard !isPrepared else { return }

        if let preparationTask {
            do {
                try await preparationTask.value
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as CelestialStateError {
                throw error
            } catch {
                throw UniverseModulePreparationError.requiredCelestialAssetsUnavailable
            }
            return
        }

        let task = Task { @MainActor [self] in
            if let loader = stateProviderLoader {
                // Reading, hashing and decoding the archive must not block the loading UI.
                let provider = try await Task.detached(priority: .userInitiated) {
                    try loader()
                }.value
                try Task.checkCancellation()
                _ = try provider.state(for: .earth, at: SimulationTime.tdbSeconds(for: now()))
                sceneSnapshotPipeline.setStateProvider(provider)
                stateProviderLoader = nil
            } else {
                _ = try sceneSnapshotPipeline.stateProvider.state(for: .earth,
                                                                  at: SimulationTime.tdbSeconds(for: now()))
            }
            let manifest = try celestialAssetManifestLoader()
            try await sceneCoordinator.prepareCelestialBodies(from: manifest)
            sceneSnapshotPipeline.setPresentationMetrics(
                Dictionary(uniqueKeysWithValues: manifest.assets.map { descriptor in
                    (descriptor.displayName, descriptor.presentationMetrics)
                })
            )
        }
        preparationTask = task

        do {
            try await task.value
            preparationTask = nil
            isPrepared = true
        } catch is CancellationError {
            preparationTask = nil
            throw CancellationError()
        } catch let error as CelestialStateError {
            preparationTask = nil
            throw error
        } catch {
            preparationTask = nil
            throw UniverseModulePreparationError.requiredCelestialAssetsUnavailable
        }
    }

    /// Shared physical state for future dated mission trajectories, independent of playback mode.
    public func celestialState(for body: CelestialBodyID, at date: Date) throws -> CelestialBodyState {
        guard date >= Date(timeIntervalSince1970: 946_684_800),
              date < Date(timeIntervalSince1970: 4_133_980_800) else { throw CelestialStateError.outsideCoverage }
        return try sceneSnapshotPipeline.stateProvider.state(for: body, at: SimulationTime.tdbSeconds(for: date))
    }

    func setViewportSize(_ size: CGSize) {
        guard size.width.isFinite,
              size.height.isFinite,
              size.width > 0,
              size.height > 0 else {
            return
        }
        viewportSize = size
        sceneCoordinator.setViewportSize(size)
    }

}

extension UniverseModuleResources {
    func followTarget(for destinationID: UUID,
                      destinations: [DestinationObject]) -> ObjectFollowTarget? {
        guard let destination = destinations.first(where: { $0.id == destinationID }) else {
            return nil
        }

        return ObjectFollowTarget(bodyName: destination.object,
                                  surfaceLocation: destination.surfaceLocation)
    }

    func followDestination(identifiedBy destinationID: UUID,
                           destinations: [DestinationObject]) {
        guard let followTarget = followTarget(for: destinationID,
                                              destinations: destinations) else {
            return
        }

        followPlanet(named: followTarget.bodyName,
                     surfaceLocation: followTarget.surfaceLocation)
    }

    func followPlanet(named name: String,
                      surfaceLocation: SurfaceLocation? = nil) {
        transferOrbitController.clearTransferOrbit()
        navigationController.cancelNavigation()
        cameraCoordinator.followPlanet(named: name,
                                       surfaceCoordinate: surfaceLocation.map {
            SurfaceCoordinate(latitudeDegrees: $0.latitudeDegrees,
                              longitudeDegrees: $0.longitudeDegrees)
        },
                                       viewportSize: viewportSize)
    }

    func focusImmersiveDestination(identifiedBy destinationID: UUID,
                                   destinations: [DestinationObject]) {
        guard let followTarget = followTarget(for: destinationID,
                                              destinations: destinations) else {
            return
        }

        focusImmersivePlanet(named: followTarget.bodyName)
    }

    func focusImmersivePlanet(named name: String) {
        transferOrbitController.clearTransferOrbit()
        navigationController.cancelNavigation()
        sceneCoordinator.clearImmersiveTransferOverview()
        sceneCoordinator.setImmersiveFocus(bodyName: name)
    }

    func clearImmersiveFocus() {
        sceneCoordinator.clearImmersiveTransferOverview()
        sceneCoordinator.clearImmersiveFocus()
    }

    func beginManualCameraControl() {
        let navigationRenderState = navigationController.routeRenderState

        transferOrbitController.beginManualCameraControl()
        sceneCoordinator.clearImmersiveTransferOverview()
        cameraCoordinator.beginManualCameraControl()
        cameraCoordinator.handOffNavigationCameraControl(
            navigation: navigationRenderState,
            snapshot: snapshotProvider.latestSnapshot,
            viewportSize: viewportSize
        )
        navigationController.beginManualCameraControl()
    }

    public func rotateCamera(translation: CGSize, velocity: CGSize = .zero) {
        beginManualCameraControl()
        cameraCoordinator.makeRotation(
            with: CGPoint(x: translation.width, y: translation.height),
            velocity: CGPoint(x: velocity.width, y: velocity.height)
        )
    }

    public func translateCamera(translation: CGSize) {
        beginManualCameraControl()
        cameraCoordinator.makeTranslation(
            with: CGPoint(x: translation.width, y: translation.height),
            viewportSize: viewportSize
        )
    }

    public func scaleCamera(by scale: Float, velocity: CGFloat = 0) {
        beginManualCameraControl()
        cameraCoordinator.makeScale(with: scale, velocity: velocity)
    }

    public func adjustImmersiveFocusRotation(translation: CGSize) -> Bool {
        sceneCoordinator.adjustImmersiveFocusRotation(translation: translation)
    }

    public func adjustImmersiveFocusScale(by scale: Float) -> Bool {
        sceneCoordinator.adjustImmersiveFocusScale(by: scale)
    }

    public func setObjectInfoOverlayFraming(isPresented: Bool,
                                            bottomInset: CGFloat,
                                            viewportHeight: CGFloat) {
        objectInfoOverlayFramingState.setPresentation(isPresented: isPresented,
                                                      bottomInset: bottomInset,
                                                      viewportHeight: viewportHeight)
    }
}

private extension CelestialAssetDescriptor {
    var presentationMetrics: CelestialBodyPresentationMetrics {
        CelestialBodyPresentationMetrics(renderRadius: renderRadius,
                                         framingRadius: framingRadius,
                                         surfaceRadius: surfaceRadius)
    }
}
