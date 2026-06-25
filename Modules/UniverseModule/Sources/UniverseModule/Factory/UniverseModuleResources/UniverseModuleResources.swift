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
    public internal(set) var navigationSnapshot: NavigationRouteSnapshot = .idle
    public internal(set) var navigationCameraFollowEnabled = true
    @ObservationIgnored private(set) var transferOrbitController: TransferOrbitController!
    @ObservationIgnored private(set) var navigationController: NavigationController!
    @ObservationIgnored private(set) lazy var sceneCoordinator = UniverseSceneCoordinator(
        planets: planets,
        snapshotProvider: snapshotProvider,
        cameraCoordinator: cameraCoordinator,
        objectInfoOverlayFramingState: objectInfoOverlayFramingState,
        navigationController: navigationController,
        transferOrbitController: transferOrbitController,
        assetRepository: assetRepository
    )
    @ObservationIgnored private(set) var viewportSize: CGSize = .zero
    @ObservationIgnored private var preparationTask: Task<Void, any Error>?
    @ObservationIgnored private var isPrepared = false

    var isTrajectoryModeActive: Bool {
        transferOrbitController.isTransferPreviewActive ||
        navigationController.isNavigationActive
    }

    public var isImmersiveFocusActive: Bool {
        sceneCoordinator.hasImmersiveFocus
    }

    init(
        assetRepository: RealityAssetRepository = RealityAssetRepository(),
        celestialAssetManifestLoader: @escaping () throws -> CelestialAssetManifest = {
            try CelestialAssetManifestLoader.load()
        }
    ) {
        planets = SolarSystemLoader.loadPlanets(from: "planets")
        sceneSnapshotPipeline = UniverseSceneSnapshotPipeline(planets: planets)
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
        navigationController = NavigationController(
            snapshotProvider: snapshotProvider,
            cameraCoordinator: cameraCoordinator,
            planets: planets,
            viewportSize: { [weak self] in
                self?.viewportSize ?? .zero
            }
        )
        navigationController.navigationSnapshotDidChange = { [weak self] snapshot in
            self?.navigationSnapshot = snapshot
        }
        navigationController.navigationCameraFollowEnabledDidChange = { [weak self] isEnabled in
            self?.navigationCameraFollowEnabled = isEnabled
        }
        navigationController.followPlanet = { [weak self] name in
            guard let self else { return }
            cameraCoordinator.followNavigationDestination(named: name,
                                                          viewportSize: viewportSize)
        }
        transferOrbitController.followPlanet = { [weak self] name in
            guard let self else { return }
            cameraCoordinator.followNavigationDestination(named: name,
                                                          viewportSize: viewportSize)
        }
    }

    public func prepare() async throws {
        guard !isPrepared else { return }

        if let preparationTask {
            do {
                try await preparationTask.value
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw UniverseModulePreparationError.requiredCelestialAssetsUnavailable
            }
            return
        }

        let task = Task { @MainActor [self] in
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
        } catch {
            preparationTask = nil
            throw UniverseModulePreparationError.requiredCelestialAssetsUnavailable
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
        sceneCoordinator.setViewportSize(size)
    }

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
        navigationController.cancelNavigation(followDestination: false)
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
        navigationController.cancelNavigation(followDestination: false)
        sceneCoordinator.setImmersiveFocus(bodyName: name)
    }

    func clearImmersiveFocus() {
        sceneCoordinator.clearImmersiveFocus()
    }

    func beginManualCameraControl() {
        navigationController.beginManualCameraControl()
        transferOrbitController.beginManualCameraControl()
        cameraCoordinator.beginManualCameraControl()
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
