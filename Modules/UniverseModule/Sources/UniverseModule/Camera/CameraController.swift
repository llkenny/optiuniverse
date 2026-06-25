#if !os(visionOS)
import UIKit

/// Handles user gestures to control the orbital camera around the scene's origin.
@MainActor
final class CameraController: NSObject, UIGestureRecognizerDelegate {

    private let cameraCoordinator: CameraCoordinator
    private let beginManualCameraControl: () -> Void
    private let isTrajectoryModeActive: () -> Bool

    init(cameraCoordinator: CameraCoordinator,
         beginManualCameraControl: @escaping () -> Void,
         isTrajectoryModeActive: @escaping () -> Bool) {

        self.cameraCoordinator = cameraCoordinator
        self.beginManualCameraControl = beginManualCameraControl
        self.isTrajectoryModeActive = isTrajectoryModeActive
        super.init()
    }

    // MARK: - Gesture handling
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        beginManualCameraControl()
        let translation = gesture.translation(in: gesture.view)
        let velocity = gesture.velocity(in: gesture.view)
        cameraCoordinator.makeRotation(with: translation, velocity: velocity)
        gesture.setTranslation(.zero, in: gesture.view)
    }

    @objc func handleTrajectoryPan(_ gesture: UIPanGestureRecognizer) {
        beginManualCameraControl()

        let translation = gesture.translation(in: gesture.view)
        let viewportSize = gesture.view?.bounds.size ?? .zero
        cameraCoordinator.makeTranslation(with: translation,
                                          viewportSize: viewportSize)
        gesture.setTranslation(.zero, in: gesture.view)
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        beginManualCameraControl()
        let gestureScale = max(Float(gesture.scale), 0.01)
        cameraCoordinator.makeScale(with: gestureScale, velocity: gesture.velocity)
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

        return isTrajectoryModeActive()
    }
}
#endif
