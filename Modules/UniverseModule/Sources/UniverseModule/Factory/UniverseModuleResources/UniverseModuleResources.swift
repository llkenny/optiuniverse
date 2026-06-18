//
//  UniverseModuleResources.swift
//  UniverseModule
//
//  Created by Codex on 24.05.2026.
//

internal import BaseModule
import Foundation
import Metal
import MetalKit
import Observation

@MainActor
@Observable
public final class UniverseModuleResources {
    let meshProvider: MeshProvider
    let planets: [Planet]
    let renderPreparationPipeline: RenderPreparationPipeline
    let cameraState: CameraState
    let cameraCoordinator: CameraCoordinator
    let snapshotProvider: SnapshotProvider
    let objectInfoOverlayFramingState: ObjectInfoOverlayFramingState
    let assetRepository: RealityAssetRepository
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

    @ObservationIgnored private(set) weak var renderer: MetalRenderer?
    @ObservationIgnored private(set) var viewportSize: CGSize = .zero

    var isTrajectoryModeActive: Bool {
        transferOrbitController.isTransferPreviewActive ||
        navigationController.isNavigationActive
    }

    init() {
        meshProvider = MeshProvider()
        planets = SolarSystemLoader.loadPlanets(from: "planets")
        renderPreparationPipeline = RenderPreparationPipeline(modelLoader: meshProvider.modelLoader,
                                                              planets: planets)
        cameraState = CameraState()
        snapshotProvider = SnapshotProvider(cameraState: cameraState,
                                            snapshotSource: renderPreparationPipeline)
        cameraCoordinator = CameraCoordinator(cameraState: cameraState,
                                              snapshotProvider: snapshotProvider)
        objectInfoOverlayFramingState = ObjectInfoOverlayFramingState()
        assetRepository = RealityAssetRepository()
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
    }

    public func prepare() async {
        await meshProvider.prepare()
    }

    func makeRenderer(for metalView: MTKView) -> MetalRenderer? {
        guard let commandQueue = meshProvider.device.makeCommandQueue() else {
            return nil
        }

        guard let renderer = MetalRenderer(metalView: metalView,
                                           device: meshProvider.device,
                                           commandQueue: commandQueue,
                                           sceneOwnershipControls: .migration,
                                           planets: planets,
                                           sceneCoordinator: sceneCoordinator) else {
            return nil
        }
        self.renderer = renderer
        navigationController.followPlanet = { [weak self] name in
            guard let self else { return }
            self.cameraCoordinator.followNavigationDestination(named: name,
                                                               viewportSize: self.viewportSize)
        }
        transferOrbitController.followPlanet = { [weak self] name in
            guard let self else { return }
            self.cameraCoordinator.followNavigationDestination(named: name,
                                                               viewportSize: self.viewportSize)
        }
        return renderer
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

    func beginManualCameraControl() {
        navigationController.beginManualCameraControl()
        transferOrbitController.beginManualCameraControl()
        cameraCoordinator.beginManualCameraControl()
    }

    public func setObjectInfoOverlayFraming(isPresented: Bool,
                                            bottomInset: CGFloat,
                                            viewportHeight: CGFloat) {
        objectInfoOverlayFramingState.setPresentation(isPresented: isPresented,
                                                      bottomInset: bottomInset,
                                                      viewportHeight: viewportHeight)
    }
}
