//
//  ZoomCameraMode.swift
//  MetalModule
//
//  Created by max on 23.05.2026.
//

import CoreFoundation

/// Zoom camera mode
final class ZoomCameraMode {

    private unowned var cameraState: CameraState

    private var zoomVelocity: Float = 0
    private let zoomSpeed: Float = 1.0
    private let damping: Float = 0.9

    init(cameraState: CameraState) {
        self.cameraState = cameraState
    }

    func apply(value: Float) {
        let zoomFactor = pow(value, zoomSpeed)
        let cameraDistance = cameraState.cameraDistance / zoomFactor
        cameraState.set(cameraDistance: cameraDistance)
    }

    // MARK: Inertia
    func addInertia(velocity: CGFloat) {
        zoomVelocity = -Float(velocity) * cameraState.cameraDistance * 0.15
    }

    func update(delta: Float) {
        guard zoomVelocity != 0 else {
            return
        }
        let cameraDistance = cameraState.cameraDistance + zoomVelocity * delta
        cameraState.set(cameraDistance: cameraDistance)
        let factor = pow(damping, delta * 60)
        zoomVelocity *= factor

        if abs(zoomVelocity) < 0.0001 { zoomVelocity = 0 }
    }
}
