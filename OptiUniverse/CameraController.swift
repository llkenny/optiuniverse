import UIKit

/// Handles user gestures to control the orbital camera around the scene's origin.
final class CameraController: NSObject {
    weak var renderer: MetalRenderer?

    // Tunable parameters
    var orbitSpeed: Float
    var zoomSpeed: Float
    var minDistance: Float
    var maxDistance: Float

    // Internal state for inertia
    private var yawVelocity: Float = 0
    private var pitchVelocity: Float = 0
    private var zoomVelocity: Float = 0
    private let damping: Float = 0.9
    private var displayLink: CADisplayLink?

    init(renderer: MetalRenderer?,
         orbitSpeed: Float = 0.01,
         zoomSpeed: Float = 1.0,
         minDistance: Float = 0.001,
         maxDistance: Float = 10000.0) {
        self.renderer = renderer
        self.orbitSpeed = orbitSpeed
        self.zoomSpeed = zoomSpeed
        self.minDistance = minDistance
        self.maxDistance = maxDistance
        super.init()
        start()
    }

    deinit {
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
            renderer.cameraYaw += yawVelocity * delta
            renderer.cameraPitch += pitchVelocity * delta
            renderer.cameraPitch = max(0.1, min(renderer.cameraPitch, .pi/2 - 0.01))
            renderer.cameraDistance = max(minDistance,
                                          min(renderer.cameraDistance + zoomVelocity * delta,
                                              maxDistance))

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
        let translation = gesture.translation(in: gesture.view)
        renderer.cameraYaw -= Float(translation.x) * orbitSpeed
        renderer.cameraPitch -= Float(translation.y) * orbitSpeed
        renderer.cameraPitch = max(0.1, min(renderer.cameraPitch, .pi/2 - 0.01))
        gesture.setTranslation(.zero, in: gesture.view)
        renderer.updateCamera()

        if gesture.state == .ended {
            let velocity = gesture.velocity(in: gesture.view)
            yawVelocity = -Float(velocity.x) * orbitSpeed * 0.1
            pitchVelocity = -Float(velocity.y) * orbitSpeed * 0.1
        }
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let renderer = renderer else { return }
        let change = Float(gesture.scale - 1) * zoomSpeed
        var distance = renderer.cameraDistance - renderer.cameraDistance * change
        distance = max(minDistance, min(distance, maxDistance))
        renderer.cameraDistance = distance
        gesture.scale = 1.0
        renderer.updateCamera()

        if gesture.state == .ended {
            zoomVelocity = -Float(gesture.velocity) * zoomSpeed
        }
    }

    @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        // Optional roll gesture – renderer currently has no roll component.
    }
}
