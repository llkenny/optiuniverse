//
//  ZoomCameraMode.swift
//  MetalModule
//
//  Created by max on 23.05.2026.
//

import CoreFoundation

/// Zoom camera mode
final class ZoomCameraMode {

    private var zoomVelocity: Float = 0
    private let zoomSpeed: Float = 1.0
    private let damping: Float = 0.9

    var hasActiveInertia: Bool {
        zoomVelocity != 0
    }

    func makeZoomTransaction(value: Float,
                             currentDistance: Float) -> CameraState.Transaction {
        let zoomFactor = pow(value, zoomSpeed)
        let cameraDistance = currentDistance / zoomFactor
        return CameraState.Transaction(cameraDistance: cameraDistance)
    }

    // MARK: Inertia
    func addInertia(velocity: CGFloat,
                    currentDistance: Float) {
        zoomVelocity = -Float(velocity) * currentDistance * 0.15
    }

    func cancelInertia() {
        zoomVelocity = 0
    }

    func update(delta: Float,
                currentDistance: Float) -> CameraState.Transaction? {
        guard hasActiveInertia else {
            return nil
        }
        let cameraDistance = currentDistance + zoomVelocity * delta
        let transaction = CameraState.Transaction(cameraDistance: cameraDistance)
        let factor = pow(damping, delta * 60)
        zoomVelocity *= factor

        if abs(zoomVelocity) < 0.0001 { zoomVelocity = 0 }

        return transaction
    }
}
