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
public enum MetalModuleFactory {
    public static func makeResources() -> MetalModuleResources {
        MetalModuleResources()
    }
}

@MainActor
public protocol MetalModuleNavigationControlling: AnyObject {
    var navigationSnapshot: NavigationRouteSnapshot { get }
    var navigationCameraFollowEnabled: Bool { get }

    func startNavigation(to destinationName: String)
    func pauseNavigation()
    func resumeNavigation()
    func cancelNavigation()
    func doneNavigation()
    func setNavigationCameraFollowEnabled(_ isEnabled: Bool)
}

@MainActor
public protocol MetalModuleTransferOrbitControlling: AnyObject {
    func showTransferOrbit(to destinationName: String)
}

@MainActor
@Observable
public final class MetalModuleResources: MetalModuleNavigationControlling,
    MetalModuleTransferOrbitControlling {
    let meshProvider: MeshProvider
    let planets: [Planet]
    let renderPreparationPipeline: RenderPreparationPipeline
    let cameraState: CameraState
    let cameraCoordinator: CameraCoordinator
    let snapshotProvider: SnapshotProvider

    public private(set) var navigationSnapshot: NavigationRouteSnapshot = .idle {
        didSet {
            if navigationSnapshot.state == .completed {
                scheduleDoneNavigation()
            } else {
                pendingDoneNavigationTask?.cancel()
            }
        }
    }
    public private(set) var navigationCameraFollowEnabled = true

    @ObservationIgnored private weak var renderer: MetalRenderer?
    @ObservationIgnored private var pendingDoneNavigationTask: Task<Void, Never>?

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

        let renderer = MetalRenderer(metalView: metalView,
                                     device: meshProvider.device,
                                     commandQueue: commandQueue,
                                     cameraState: cameraState,
                                     planets: planets,
                                     snapshotProvider: snapshotProvider,
                                     navigationStatePublisher: self)
        self.renderer = renderer
        cameraCoordinator.renderer = renderer
        return renderer
    }

    public func showTransferOrbit(to destinationName: String) {
        renderer?.showTransferOrbit(to: destinationName)
    }

    public func startNavigation(to destinationName: String) {
        renderer?.startNavigation(to: destinationName)
    }

    public func pauseNavigation() {
        renderer?.pauseNavigation()
    }

    public func resumeNavigation() {
        renderer?.resumeNavigation()
    }

    public func cancelNavigation() {
        renderer?.cancelNavigation()
    }

    public func doneNavigation() {
        renderer?.doneNavigation()
    }

    public func setNavigationCameraFollowEnabled(_ isEnabled: Bool) {
        navigationCameraFollowEnabled = isEnabled
        renderer?.setNavigationCameraFollowEnabled(isEnabled)
    }

    private func scheduleDoneNavigation() {
        let routeID = navigationSnapshot.routeID

        pendingDoneNavigationTask?.cancel()
        pendingDoneNavigationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(1_100))
            } catch {
                return
            }

            await MainActor.run {
                guard let self,
                      self.navigationSnapshot.state == .completed,
                      self.navigationSnapshot.routeID == routeID else {
                    return
                }

                self.doneNavigation()
            }
        }
    }
}

extension MetalModuleResources: NavigationRenderStatePublishing {
    func publishNavigationSnapshot(_ snapshot: NavigationRouteSnapshot) {
        navigationSnapshot = snapshot
    }

    func publishNavigationCameraFollowEnabled(_ isEnabled: Bool) {
        navigationCameraFollowEnabled = isEnabled
    }
}
