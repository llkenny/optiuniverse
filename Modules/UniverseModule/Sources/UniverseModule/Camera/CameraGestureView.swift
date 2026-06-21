import SwiftUI
import UIKit

/// Input-only overlay for the RealityKit scene.
struct CameraGestureView: UIViewRepresentable {
    let resources: UniverseModuleResources

    func makeCoordinator() -> CameraController {
        CameraController(
            cameraCoordinator: resources.cameraCoordinator,
            beginManualCameraControl: { [resources] in
                resources.beginManualCameraControl()
            },
            isTrajectoryModeActive: { [resources] in
                resources.isTrajectoryModeActive
            }
        )
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isOpaque = false
        view.backgroundColor = .clear
        Self.installGestureRecognizers(on: view, cameraController: context.coordinator)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        resources.setViewportSize(view.bounds.size)
    }

    static func installGestureRecognizers(
        on view: UIView,
        cameraController: CameraController
    ) {
        let panGesture = UIPanGestureRecognizer(
            target: cameraController,
            action: #selector(CameraController.handlePan(_:))
        )
        panGesture.maximumNumberOfTouches = 1
        view.addGestureRecognizer(panGesture)

        let trajectoryPanGesture = UIPanGestureRecognizer(
            target: cameraController,
            action: #selector(CameraController.handleTrajectoryPan(_:))
        )
        trajectoryPanGesture.minimumNumberOfTouches = 2
        trajectoryPanGesture.maximumNumberOfTouches = 2
        trajectoryPanGesture.delegate = cameraController
        view.addGestureRecognizer(trajectoryPanGesture)

        view.addGestureRecognizer(
            UIPinchGestureRecognizer(
                target: cameraController,
                action: #selector(CameraController.handlePinch(_:))
            )
        )
        view.addGestureRecognizer(
            UIRotationGestureRecognizer(
                target: cameraController,
                action: #selector(CameraController.handleRotation(_:))
            )
        )
    }
}
