//
//  OrbitCameraMode.swift
//  MetalModule
//
//  Created by max on 20.05.2026.
//

import simd
import CoreFoundation

/// Orbit camera mode
final class OrbitCameraMode {

    private unowned var cameraState: CameraState

    // Inertia
    private let orbitSpeed: Float = 0.01
    private var yawVelocity: Float = 0
    private var pitchVelocity: Float = 0
    private let damping: Float = 0.9

    init(cameraState: CameraState) {
        self.cameraState = cameraState
    }

    func apply(horizontal horizontalAngle: Float, vertical verticalAngle: Float) {
        cameraState.normalizeCameraOrientation()

        var cameraOrientation = cameraState.cameraOrientation
        let rightVector = normalize(cameraOrientation.act(SIMD3<Float>(1, 0, 0)))
        let upVector = normalize(cameraOrientation.act(SIMD3<Float>(0, 1, 0)))
        let horizontalRotation = simd_quatf(angle: horizontalAngle, axis: upVector)
        let verticalRotation = simd_quatf(angle: verticalAngle, axis: rightVector)

        cameraOrientation = simd_normalize(verticalRotation * horizontalRotation * cameraOrientation)
        cameraState.set(cameraOrientation: cameraOrientation)
    }

    // MARK: Inertia
    func addInertia(velocity: CGPoint) {
        yawVelocity = Float(velocity.x) * orbitSpeed * 0.1
        pitchVelocity = Float(velocity.y) * orbitSpeed * 0.1
    }

    func update(delta: Float) {
        guard yawVelocity != 0 || pitchVelocity != 0 else {
            return
        }
        apply(horizontal: yawVelocity * delta,
              vertical: -pitchVelocity * delta)

        let factor = pow(damping, delta * 60)
        yawVelocity *= factor
        pitchVelocity *= factor

        if abs(yawVelocity) < 0.0001 { yawVelocity = 0 }
        if abs(pitchVelocity) < 0.0001 { pitchVelocity = 0 }
    }
}
