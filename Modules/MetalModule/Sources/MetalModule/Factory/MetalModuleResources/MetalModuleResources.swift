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

    public internal(set) var navigationSnapshot: NavigationRouteSnapshot = .idle {
        didSet {
            if navigationSnapshot.state == .completed {
                scheduleDoneNavigation()
            } else {
                pendingDoneNavigationTask?.cancel()
            }
        }
    }
    public internal(set) var navigationCameraFollowEnabled = true

    @ObservationIgnored private(set) weak var renderer: MetalRenderer?
    @ObservationIgnored var pendingDoneNavigationTask: Task<Void, Never>?

    init() {
        meshProvider = MeshProvider()
        planets = SolarSystemLoader.loadPlanets(from: "planets")
        renderPreparationPipeline = RenderPreparationPipeline(modelLoader: meshProvider.modelLoader,
                                                              planets: planets)
        cameraState = CameraState()
        cameraCoordinator = CameraCoordinator(cameraState: cameraState)
        snapshotProvider = SnapshotProvider(snapshotSource: renderPreparationPipeline)
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
                                           navigationStatePublisher: self) else {
            return nil
        }
        self.renderer = renderer
        cameraCoordinator.activate(renderer: renderer)
        return renderer
    }
}
