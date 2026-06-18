import MetalKit
import SwiftUI

struct LegacyMetalView: UIViewRepresentable {
    let resources: UniverseModuleResources

    func makeCoordinator() -> RendererCoordinator {
        RendererCoordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let metalView = MTKView()
        metalView.preferredFramesPerSecond = 60
        metalView.enableSetNeedsDisplay = true
        metalView.isPaused = false
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        context.coordinator.renderer = resources.makeRenderer(for: metalView)
        let cameraController = CameraController(
            cameraCoordinator: resources.cameraCoordinator,
            beginManualCameraControl: { [resources] in
                resources.beginManualCameraControl()
            },
            isTrajectoryModeActive: { [resources] in
                resources.isTrajectoryModeActive
            }
        )
        context.coordinator.cameraController = cameraController
        setupGestures(metalView: metalView,
                      cameraController: cameraController)
        return metalView
    }

    func updateUIView(_ metalView: MTKView, context: Context) {
        resources.setViewportSize(metalView.bounds.size)
    }

    static func dismantleUIView(_ metalView: MTKView,
                                coordinator: RendererCoordinator) {
        coordinator.renderer?.dismantle()
        coordinator.cameraController = nil
        coordinator.renderer = nil
    }

    private func setupGestures(metalView: MTKView,
                               cameraController: CameraController) {
        let panGesture = UIPanGestureRecognizer(
            target: cameraController,
            action: #selector(CameraController.handlePan(_:)))
        panGesture.maximumNumberOfTouches = 1
        metalView.addGestureRecognizer(panGesture)

        let trajectoryPanGesture = UIPanGestureRecognizer(
            target: cameraController,
            action: #selector(CameraController.handleTrajectoryPan(_:)))
        trajectoryPanGesture.minimumNumberOfTouches = 2
        trajectoryPanGesture.maximumNumberOfTouches = 2
        trajectoryPanGesture.delegate = cameraController
        metalView.addGestureRecognizer(trajectoryPanGesture)

        let pinchGesture = UIPinchGestureRecognizer(
            target: cameraController,
            action: #selector(CameraController.handlePinch(_:)))
        metalView.addGestureRecognizer(pinchGesture)

        let rotationGesture = UIRotationGestureRecognizer(
            target: cameraController,
            action: #selector(CameraController.handleRotation(_:)))
        metalView.addGestureRecognizer(rotationGesture)
    }
}
