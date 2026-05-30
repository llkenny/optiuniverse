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
        let localTarget = destinationPosition - currentPoint
        let localEye = trailingOffset
        let viewDirectionInput = localTarget - localEye
        let viewDirection = simd_length_squared(viewDirectionInput) > 0.000001
        ? normalize(viewDirectionInput)
        : SIMD3<Float>(0, 0, -1)
        let cameraUp = makeCameraUp(viewDirection: viewDirection)

        return CameraState.Transaction(cameraTarget: currentPoint,
                                       cameraDistance: max(simd_length(localEye), CameraFit.minimumNearPlane),
                                       cameraOrientation: makeCameraOrientation(localEye: localEye,
                                                                                cameraUp: cameraUp))
    }

    func makeNavigationArrivalTransaction(position: SIMD3<Float>,
                                          target: SIMD3<Float>) -> CameraState.Transaction {
        let localEye = position - target
        let viewDirection = simd_length_squared(-localEye) > 0.000001
        ? normalize(-localEye)
        : SIMD3<Float>(0, 0, -1)
        let cameraUp = makeCameraUp(viewDirection: viewDirection)

        return CameraState.Transaction(cameraTarget: target,
                                       cameraDistance: max(simd_length(localEye), CameraFit.minimumNearPlane),
                                       cameraOrientation: makeCameraOrientation(localEye: localEye,
                                                                                cameraUp: cameraUp))
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

    private func makeCameraOrientation(localEye: SIMD3<Float>,
                                       cameraUp: SIMD3<Float>) -> simd_quatf {
        let forward = simd_length_squared(localEye) > 0.000001
        ? normalize(localEye)
        : SIMD3<Float>(0, 0, 1)
        let upSeed = simd_length_squared(cameraUp) > 0.000001
        ? normalize(cameraUp)
        : SIMD3<Float>(0, 1, 0)
        let candidateUp = abs(simd_dot(forward, upSeed)) > 0.94
        ? SIMD3<Float>(1, 0, 0)
        : upSeed
        let right = normalize(simd_cross(candidateUp, forward))
        let cameraUpDirection = normalize(simd_cross(forward, right))

        return simd_normalize(simd_quatf(
            float3x3(columns: (right, cameraUpDirection, forward))
        ))
    }
}
