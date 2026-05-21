//
//  OrbitCameraTransition.swift
//  MetalModule
//
//  Created by max on 20.05.2026.
//

import simd

/// Transformations for the orbit camera mode
final class OrbitCameraTransition {

    private unowned var cameraState: CameraState

    init(cameraState: CameraState) {
        self.cameraState = cameraState
    }

    func orbitCamera(horizontal horizontalAngle: Float, vertical verticalAngle: Float) {
        cameraState.normalizeCameraOrientation()

        var cameraOrientation = cameraState.cameraOrientation
        let rightVector = normalize(cameraOrientation.act(SIMD3<Float>(1, 0, 0)))
        let upVector = normalize(cameraOrientation.act(SIMD3<Float>(0, 1, 0)))
        let horizontalRotation = simd_quatf(angle: horizontalAngle, axis: upVector)
        let verticalRotation = simd_quatf(angle: verticalAngle, axis: rightVector)

        cameraOrientation = simd_normalize(verticalRotation * horizontalRotation * cameraOrientation)
        cameraState.set(cameraOrientation: cameraOrientation)
    }
}
