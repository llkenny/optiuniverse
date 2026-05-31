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

    // Inertia
    private let orbitSpeed: Float = 0.01
    private var yawVelocity: Float = 0
    private var pitchVelocity: Float = 0
    private let damping: Float = 0.9

    var hasActiveInertia: Bool {
        yawVelocity != 0 || pitchVelocity != 0
    }

    func makeOrbitTransaction(horizontal horizontalAngle: Float,
                              vertical verticalAngle: Float,
                              cameraOrientation currentOrientation: simd_quatf) -> CameraState.Transaction {
        var cameraOrientation = simd_normalize(currentOrientation)
        let rightVector = normalize(cameraOrientation.act(SIMD3<Float>(1, 0, 0)))
        let upVector = normalize(cameraOrientation.act(SIMD3<Float>(0, 1, 0)))
        let horizontalRotation = simd_quatf(angle: horizontalAngle, axis: upVector)
        let verticalRotation = simd_quatf(angle: verticalAngle, axis: rightVector)

        cameraOrientation = simd_normalize(verticalRotation * horizontalRotation * cameraOrientation)
        return CameraState.Transaction(cameraOrientation: cameraOrientation)
    }

    // MARK: Inertia
    func addInertia(velocity: CGPoint) {
        yawVelocity = Float(velocity.x) * orbitSpeed * 0.1
        pitchVelocity = Float(velocity.y) * orbitSpeed * 0.1
    }

    func cancelInertia() {
        yawVelocity = 0
        pitchVelocity = 0
    }

    func update(delta: Float,
                cameraOrientation: simd_quatf) -> CameraState.Transaction? {
        guard hasActiveInertia else {
            return nil
        }
        let transaction = makeOrbitTransaction(horizontal: yawVelocity * delta,
                                               vertical: -pitchVelocity * delta,
                                               cameraOrientation: cameraOrientation)

        let factor = pow(damping, delta * 60)
        yawVelocity *= factor
        pitchVelocity *= factor

        if abs(yawVelocity) < 0.0001 { yawVelocity = 0 }
        if abs(pitchVelocity) < 0.0001 { pitchVelocity = 0 }

        return transaction
    }
}
