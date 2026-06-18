//
//  TrajectoryCameraMode.swift
//  UniverseModule
//
//  Created by max on 20.05.2026.
//

import simd
import CoreGraphics

/// Transformations for the trajectory camera mode
final class TrajectoryCameraMode {

    struct CameraInput {
        let distance: Float
        let orientation: simd_quatf
        let target: SIMD3<Float>
    }

    private let trajectoryPanSpeed: Float = 1.0

    func makePanTransaction(width: Float,
                            height: Float,
                            translation: CGPoint,
                            speed: Float,
                            camera: CameraInput) -> CameraState.Transaction {
        let cameraOrientation = simd_normalize(camera.orientation)
        let width = max(width, 1)
        let height = max(height, 1)
        let aspect = width / height
        let visibleHeight = (
            2 * max(camera.distance, CameraFit.minimumNearPlane)
            * tan(CameraFit.verticalFieldOfView / 2)
        )
        let visibleWidth = visibleHeight * aspect
        let horizontal = Float(translation.x) / width * visibleWidth * speed
        let vertical = Float(translation.y) / height * visibleHeight * speed
        let rightVector = normalize(cameraOrientation.act(SIMD3<Float>(1, 0, 0)))
        let upVector = normalize(cameraOrientation.act(SIMD3<Float>(0, 1, 0)))

        var cameraTarget = camera.target
        cameraTarget += (rightVector * horizontal) + (upVector * vertical)
        return CameraState.Transaction(cameraTarget: cameraTarget)
    }

    func makePanTransaction(translation: CGPoint,
                            viewportSize: CGSize,
                            camera: CameraInput) -> CameraState.Transaction {
        makePanTransaction(
            width: Float(viewportSize.width),
            height: Float(viewportSize.height),
            translation: translation,
            speed: trajectoryPanSpeed,
            camera: camera
        )
    }
}
