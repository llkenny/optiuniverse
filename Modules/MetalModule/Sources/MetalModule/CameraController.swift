import UIKit

/// Handles user gestures to control the orbital camera around the scene's origin.
@MainActor
final class CameraController: NSObject, UIGestureRecognizerDelegate {

    private let cameraState: CameraState
    weak var renderer: MetalRenderer?

    private var orbitCameraTransition: OrbitCameraTransition

    // Tunable parameters
    private let orbitSpeed: Float
    private let zoomSpeed: Float
    private let trajectoryPanSpeed: Float

    // Internal state for inertia
    private var yawVelocity: Float = 0
    private var pitchVelocity: Float = 0
    private var zoomVelocity: Float = 0
    private let damping: Float = 0.9
    private var displayLink: CADisplayLink?

    init(cameraState: CameraState,
         renderer: MetalRenderer?,
         orbitSpeed: Float = 0.01,
         zoomSpeed: Float = 1.0,
         trajectoryPanSpeed: Float = 1.0) {

        self.cameraState = cameraState
        self.renderer = renderer

        orbitCameraTransition = .init(cameraState: cameraState)

        self.orbitSpeed = orbitSpeed
        self.zoomSpeed = zoomSpeed
        self.trajectoryPanSpeed = trajectoryPanSpeed
        super.init()
        start()
    }

    func stop() {
        displayLink?.invalidate()
    }

    private func start() {
        displayLink = CADisplayLink(target: self, selector: #selector(step(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func step(_ link: CADisplayLink) {
        let delta = Float(link.duration)
        update(delta: delta)
    }

    private func update(delta: Float) {
        guard let renderer = renderer else { return }
        if yawVelocity != 0 || pitchVelocity != 0 || zoomVelocity != 0 {
            orbitCameraTransition.orbitCamera(horizontal: yawVelocity * delta,
                                              vertical: -pitchVelocity * delta)
            let cameraDistance = cameraState.cameraDistance + zoomVelocity * delta
            cameraState.set(cameraDistance: cameraDistance)

            let factor = pow(damping, delta * 60)
            yawVelocity *= factor
            pitchVelocity *= factor
            zoomVelocity *= factor

            if abs(yawVelocity) < 0.0001 { yawVelocity = 0 }
            if abs(pitchVelocity) < 0.0001 { pitchVelocity = 0 }
            if abs(zoomVelocity) < 0.0001 { zoomVelocity = 0 }

            renderer.updateCamera()
        }
    }

    // MARK: - Gesture handling
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let renderer = renderer else { return }
        renderer.beginManualCameraControl()

        if gesture.state == .began {
            stopInertia()
        }

        let translation = gesture.translation(in: gesture.view)
        orbitCameraTransition.orbitCamera(horizontal: Float(translation.x) * orbitSpeed,
                                          vertical: -Float(translation.y) * orbitSpeed)
        gesture.setTranslation(.zero, in: gesture.view)
        renderer.updateCamera()

        if gesture.state == .ended {
            let velocity = gesture.velocity(in: gesture.view)
            yawVelocity = Float(velocity.x) * orbitSpeed * 0.1
            pitchVelocity = Float(velocity.y) * orbitSpeed * 0.1
        } else if gesture.state == .cancelled || gesture.state == .failed {
            yawVelocity = 0
            pitchVelocity = 0
        }
    }

    @objc func handleTrajectoryPan(_ gesture: UIPanGestureRecognizer) {
        guard let renderer = renderer else { return }
        renderer.beginManualCameraControl()

        if gesture.state == .began {
            stopInertia()
        }

        let translation = gesture.translation(in: gesture.view)
        renderer.panTrajectoryCamera(byScreenTranslation: translation,
                                     speed: trajectoryPanSpeed)
        gesture.setTranslation(.zero, in: gesture.view)

        if gesture.state == .cancelled || gesture.state == .failed {
            stopInertia()
        }
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let renderer = renderer else { return }
        renderer.beginManualCameraControl()

        if gesture.state == .began {
            stopInertia()
        }

        let gestureScale = max(Float(gesture.scale), 0.01)
        let zoomFactor = pow(gestureScale, zoomSpeed)
        let cameraDistance = cameraState.cameraDistance / zoomFactor
        cameraState.set(cameraDistance: cameraDistance)
        gesture.scale = 1.0
        renderer.updateCamera()

        if gesture.state == .ended {
            zoomVelocity = -Float(gesture.velocity) * cameraState.cameraDistance * 0.15
        } else if gesture.state == .cancelled || gesture.state == .failed {
            zoomVelocity = 0
        }
    }

    private func stopInertia() {
        yawVelocity = 0
        pitchVelocity = 0
        zoomVelocity = 0
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
