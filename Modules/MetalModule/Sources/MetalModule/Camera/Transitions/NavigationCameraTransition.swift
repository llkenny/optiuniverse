//
//  NavigationCameraTransition.swift
//  MetalModule
//
//  Created by max on 20.05.2026.
//

import simd

/// Transformations for the navigation camera mode
final class NavigationCameraTransition {

    private unowned var cameraState: CameraState

    init(cameraState: CameraState) {
        self.cameraState = cameraState
    }

    func makeNavigationFollowViewMatrix(route: NavigationRoute,
                                        currentPoint: SIMD3<Float>,
                                        destinationPosition: SIMD3<Float>,
                                        trailingOffset: SIMD3<Float>) -> float4x4 {
        let cameraEye = currentPoint + trailingOffset
        let localTarget = destinationPosition - currentPoint
        let localEye = cameraEye - currentPoint

        cameraState.set(cameraTarget: currentPoint)
        cameraState.set(cameraPosition: cameraEye)
        cameraState.set(cameraOffset: localEye)
        cameraState.set(cameraDistance: max(simd_length(cameraState.cameraOffset), CameraFit.minimumNearPlane))

        let fallbackUp = SIMD3<Float>(0, 1, 0)
        let viewDirection = normalize(localTarget - localEye)
        let candidateUp = abs(simd_dot(viewDirection, fallbackUp)) > 0.94
        ? SIMD3<Float>(1, 0, 0)
        : fallbackUp
        let right = normalize(simd_cross(candidateUp, viewDirection))
        let cameraUp = normalize(simd_cross(viewDirection, right))
        cameraState.set(cameraUp: cameraUp)

        return float4x4.lookAt(
            eye: localEye,
            target: localTarget,
            upVector: cameraUp
        )
    }

    func makeNavigationArrivalViewMatrix(position: SIMD3<Float>,
                                         target: SIMD3<Float>) -> float4x4 {
        let localEye = position - target
        let viewDirection = simd_length_squared(-localEye) > 0.000001
        ? normalize(-localEye)
        : SIMD3<Float>(0, 0, -1)
        let fallbackUp = SIMD3<Float>(0, 1, 0)
        let candidateUp = abs(simd_dot(viewDirection, fallbackUp)) > 0.94
        ? SIMD3<Float>(1, 0, 0)
        : fallbackUp
        let right = normalize(simd_cross(candidateUp, viewDirection))

        cameraState.set(cameraTarget: target)
        cameraState.set(cameraOffset: localEye)
        cameraState.set(cameraPosition: position)
        cameraState.set(cameraDistance: max(simd_length(localEye), CameraFit.minimumNearPlane))
        let cameraUp = normalize(simd_cross(viewDirection, right))
        cameraState.set(cameraUp: cameraUp)

        return float4x4.lookAt(
            eye: localEye,
            target: .zero,
            upVector: cameraUp
        )
    }

    func set(destinationPosition: SIMD3<Float>) {
        cameraState.set(cameraTarget: destinationPosition)
        cameraState.set(cameraOffset: cameraState.cameraPosition - destinationPosition)
        cameraState.set(cameraDistance: max(simd_length(cameraState.cameraOffset), CameraFit.minimumNearPlane))
        alignCameraOrientationToCurrentLookAt()
    }

    private func alignCameraOrientationToCurrentLookAt() {
        guard simd_length_squared(cameraState.cameraOffset) > 0.000001 else { return }

        let forward = normalize(cameraState.cameraOffset)
        let fallbackUp = SIMD3<Float>(0, 1, 0)
        let upSeed = simd_length_squared(cameraState.cameraUp) > 0.000001
        ? normalize(cameraState.cameraUp)
        : fallbackUp
        let candidateUp = abs(simd_dot(forward, upSeed)) > 0.94
        ? SIMD3<Float>(1, 0, 0)
        : upSeed
        let right = normalize(simd_cross(candidateUp, forward))
        let cameraUpDirection = normalize(simd_cross(forward, right))

        cameraState.set(cameraUp: cameraUpDirection)
        let cameraOrientation = simd_normalize(simd_quatf(
            float3x3(columns: (right, cameraUpDirection, forward))
        ))
        cameraState.set(cameraOrientation: cameraOrientation)
    }
}
