//
//  MetalModuleResources.swift
//  MetalModule
//
//  Created by Codex on 24.05.2026.
//

import Metal
import MetalKit
import Observation

@MainActor
@Observable
public final class MetalModuleResources {
    let meshProvider: MeshProvider
    let planets: [Planet]
    let renderPreparationPipeline: RenderPreparationPipeline
    let cameraState: CameraState
    let cameraCoordinator: CameraCoordinator
    let snapshotProvider: SnapshotProvider
    public internal(set) var navigationSnapshot: NavigationRouteSnapshot = .idle
    public internal(set) var navigationCameraFollowEnabled = true
    @ObservationIgnored private(set) var transferOrbitController: TransferOrbitController!
    @ObservationIgnored private(set) var navigationController: NavigationController!

    @ObservationIgnored private(set) weak var renderer: MetalRenderer?

    init() {
        meshProvider = MeshProvider()
        planets = SolarSystemLoader.loadPlanets(from: "planets")
        renderPreparationPipeline = RenderPreparationPipeline(modelLoader: meshProvider.modelLoader,
                                                              planets: planets)
        cameraState = CameraState()
        cameraCoordinator = CameraCoordinator(cameraState: cameraState)
        snapshotProvider = SnapshotProvider(cameraState: cameraState,
                                            snapshotSource: renderPreparationPipeline)
        transferOrbitController = TransferOrbitController(
            snapshotProvider: snapshotProvider,
            cameraCoordinator: cameraCoordinator,
            planets: planets,
            viewportSize: { [weak self] in
                self?.renderer?.metalView.bounds.size ?? .zero
            }
        )
        navigationController = NavigationController(
            snapshotProvider: snapshotProvider,
            cameraCoordinator: cameraCoordinator,
            planets: planets,
            viewportSize: { [weak self] in
                self?.renderer?.metalView.bounds.size ?? .zero
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
                                           cameraState: cameraState,
                                           planets: planets,
                                           snapshotProvider: snapshotProvider,
                                           navigationController: navigationController,
                                           transferOrbitController: transferOrbitController) else {
            return nil
        }
        self.renderer = renderer
        navigationController.followPlanet = { [weak renderer] name in
            renderer?.followNavigationDestination(named: name)
        }
        transferOrbitController.followPlanet = { [weak renderer] name in
            renderer?.followNavigationDestination(named: name)
        }
        cameraCoordinator.activate(renderer: renderer)
        return renderer
    }
}
