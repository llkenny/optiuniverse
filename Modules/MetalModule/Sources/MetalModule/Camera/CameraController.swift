import UIKit

/// Handles user gestures to control the orbital camera around the scene's origin.
@MainActor
final class CameraController: NSObject, UIGestureRecognizerDelegate {

    // TODO: Remove renderer probably too
    weak var renderer: MetalRenderer?

    private let cameraCoordniator: CameraCoordinator

    // TODO: Remove cameraState and orbitCameraMode
    private let cameraState: CameraState
    private var orbitCameraMode: OrbitCameraMode

    // Tunable parameters
    private let orbitSpeed: Float

    init(cameraState: CameraState,
         renderer: MetalRenderer?,
         orbitSpeed: Float = 0.01) {

        self.cameraState = cameraState
        self.renderer = renderer
        cameraCoordniator = .init(cameraState: cameraState)
        cameraCoordniator.renderer = renderer

        orbitCameraMode = .init(cameraState: cameraState)

        self.orbitSpeed = orbitSpeed
        super.init()
    }

    // MARK: - Gesture handling
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let renderer = renderer else { return }
        renderer.beginManualCameraControl()
        let translation = gesture.translation(in: gesture.view)
        let velocity = gesture.velocity(in: gesture.view)
        cameraCoordniator.makeRotation(with: translation, velocity: velocity)
        gesture.setTranslation(.zero, in: gesture.view)
    }

    @objc func handleTrajectoryPan(_ gesture: UIPanGestureRecognizer) {
        guard let renderer = renderer else { return }
        renderer.beginManualCameraControl()

        let translation = gesture.translation(in: gesture.view)
        cameraCoordniator.makeTranslation(with: translation)
        gesture.setTranslation(.zero, in: gesture.view)
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let renderer = renderer else { return }
        renderer.beginManualCameraControl()
        let gestureScale = max(Float(gesture.scale), 0.01)
        cameraCoordniator.makeScale(with: gestureScale, velocity: gesture.velocity)
        gesture.scale = 1.0
    }

    @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        // Optional roll gesture – renderer currently has no roll component.
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer,
              panGesture.minimumNumberOfTouches == 2 else {
            return true
        }

        return renderer?.isTrajectoryModeActive == true
    }
}
