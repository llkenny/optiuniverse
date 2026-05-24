//
//  TrajectoryCameraMode.swift
//  MetalModule
//
//  Created by max on 20.05.2026.
//

import simd
import CoreFoundation

/// Transformations for the trajectory camera mode
final class TrajectoryCameraMode {

    private unowned var cameraState: CameraState

    private let trajectoryPanSpeed: Float = 1.0

    init(cameraState: CameraState) {
        self.cameraState = cameraState
    }

    func updateForPanTrajectory(width: Float,
                                height: Float,
                                translation: CGPoint,
                                speed: Float) {
        cameraState.normalizeCameraOrientation()

        let cameraDistance = cameraState.cameraDistance
        let cameraOrientation = cameraState.cameraOrientation

        let width = max(width, 1)
        let height = max(height, 1)
        let aspect = width / height
        let visibleHeight = (
            2 * max(cameraDistance, CameraFit.minimumNearPlane)
            * tan(CameraFit.verticalFieldOfView / 2)
        )
        let visibleWidth = visibleHeight * aspect
        let horizontal = Float(translation.x) / width * visibleWidth * speed
        let vertical = Float(translation.y) / height * visibleHeight * speed
        let rightVector = normalize(cameraOrientation.act(SIMD3<Float>(1, 0, 0)))
        let upVector = normalize(cameraOrientation.act(SIMD3<Float>(0, 1, 0)))

        var cameraTarget = cameraState.cameraTarget
        cameraTarget += (rightVector * horizontal) + (upVector * vertical)
        cameraState.set(cameraTarget: cameraTarget)
    }

    func apply(translation: CGPoint) {
        updateForPanTrajectory(
            width: Float(300),
            height: Float(400),
            translation: translation,
            speed: trajectoryPanSpeed
        )
    }
}
