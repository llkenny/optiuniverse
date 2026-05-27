//
//  NavigationCameraMode.swift
//  MetalModule
//
//  Created by max on 20.05.2026.
//

import simd

/// Computes transactional camera mutations for route navigation.
final class NavigationCameraMode {

    func makeNavigationFollowTransaction(currentPoint: SIMD3<Float>,
                                         destinationPosition: SIMD3<Float>,
                                         trailingOffset: SIMD3<Float>) -> CameraState.Transaction {
        let cameraEye = currentPoint + trailingOffset
        let localTarget = destinationPosition - currentPoint
        let localEye = cameraEye - currentPoint
        let cameraUp = makeCameraUp(viewDirection: normalize(localTarget - localEye))

        return CameraState.Transaction(cameraTarget: currentPoint,
                                       cameraPosition: cameraEye,
                                       cameraDistance: max(simd_length(localEye), CameraFit.minimumNearPlane),
                                       cameraUp: cameraUp,
                                       cameraOffset: localEye)
    }

    func makeNavigationArrivalTransaction(position: SIMD3<Float>,
                                          target: SIMD3<Float>) -> CameraState.Transaction {
        let localEye = position - target
        let viewDirection = simd_length_squared(-localEye) > 0.000001
        ? normalize(-localEye)
        : SIMD3<Float>(0, 0, -1)
        let cameraUp = makeCameraUp(viewDirection: viewDirection)

        return CameraState.Transaction(cameraTarget: target,
                                       cameraPosition: position,
                                       cameraDistance: max(simd_length(localEye), CameraFit.minimumNearPlane),
                                       cameraUp: cameraUp,
                                       cameraOffset: localEye)
    }

    func makeDestinationTransaction(destinationPosition: SIMD3<Float>,
                                    cameraPosition: SIMD3<Float>,
                                    cameraUp: SIMD3<Float>) -> CameraState.Transaction? {
        let localEye = cameraPosition - destinationPosition
        guard simd_length_squared(localEye) > 0.000001 else { return nil }

        let forward = normalize(localEye)
        let upSeed = simd_length_squared(cameraUp) > 0.000001
        ? normalize(cameraUp)
        : SIMD3<Float>(0, 1, 0)
        let candidateUp = abs(simd_dot(forward, upSeed)) > 0.94
        ? SIMD3<Float>(1, 0, 0)
        : upSeed
        let right = normalize(simd_cross(candidateUp, forward))
        let cameraUpDirection = normalize(simd_cross(forward, right))
        let cameraOrientation = simd_normalize(simd_quatf(
            float3x3(columns: (right, cameraUpDirection, forward))
        ))

        return CameraState.Transaction(cameraTarget: destinationPosition,
                                       cameraDistance: max(simd_length(localEye), CameraFit.minimumNearPlane),
                                       cameraUp: cameraUpDirection,
                                       cameraOffset: localEye,
                                       cameraOrientation: cameraOrientation)
    }

    private func makeCameraUp(viewDirection: SIMD3<Float>) -> SIMD3<Float> {
        let fallbackUp = SIMD3<Float>(0, 1, 0)
        let candidateUp = abs(simd_dot(viewDirection, fallbackUp)) > 0.94
        ? SIMD3<Float>(1, 0, 0)
        : fallbackUp
        let right = normalize(simd_cross(candidateUp, viewDirection))
        return normalize(simd_cross(viewDirection, right))
    }
}
