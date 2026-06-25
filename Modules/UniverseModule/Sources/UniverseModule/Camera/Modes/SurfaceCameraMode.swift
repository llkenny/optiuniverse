//
//  SurfaceCameraMode.swift
//  UniverseModule
//
//  Created by Codex on 06.06.2026.
//

import simd

final class SurfaceCameraMode {
    struct Frame {
        let target: SIMD3<Float>
        let distance: Float
        let orientation: simd_quatf
    }

    private let epsilon: Float = 0.000001

    func makeSurfaceFrame(bodyName: String,
                          coordinate: SurfaceCoordinate,
                          snapshot: UniverseSceneSnapshot,
                          currentPose: CameraPose) -> Frame? {
        guard let planet = snapshot.planet(named: bodyName) else {
            return nil
        }

        let surfacePoint = SurfaceCoordinateMath.worldSurfacePoint(on: planet,
                                                                   at: coordinate)
        let normalInput = surfacePoint - planet.worldPosition
        guard simd_length_squared(normalInput) > epsilon * epsilon else {
            return nil
        }

        let normal = simd_normalize(normalInput)
        let orientation = makeCameraOrientation(forward: normal,
                                                upSeed: currentPose.upVector)

        return Frame(target: planet.worldPosition,
                     distance: currentPose.distance,
                     orientation: orientation)
    }

    func makeSurfaceTransaction(frame: Frame) -> CameraState.Transaction {
        CameraState.Transaction(cameraTarget: frame.target,
                                cameraDistance: frame.distance,
                                cameraOrientation: frame.orientation)
    }

    private func makeCameraOrientation(forward: SIMD3<Float>,
                                       upSeed: SIMD3<Float>) -> simd_quatf {
        let fallbackUp = SIMD3<Float>(0, 1, 0)
        let normalizedUpSeed = simd_length_squared(upSeed) > epsilon * epsilon
        ? simd_normalize(upSeed)
        : fallbackUp
        let candidateUp = abs(simd_dot(forward, normalizedUpSeed)) > 0.94
        ? fallbackUpVector(forward: forward)
        : normalizedUpSeed
        let right = simd_normalize(simd_cross(candidateUp, forward))
        let cameraUpDirection = simd_normalize(simd_cross(forward, right))

        return simd_normalize(simd_quatf(
            float3x3(columns: (right, cameraUpDirection, forward))
        ))
    }

    private func fallbackUpVector(forward: SIMD3<Float>) -> SIMD3<Float> {
        let candidates = [
            SIMD3<Float>(1, 0, 0),
            SIMD3<Float>(0, 1, 0),
            SIMD3<Float>(0, 0, 1)
        ]

        return candidates.min {
            abs(simd_dot(forward, $0)) < abs(simd_dot(forward, $1))
        } ?? SIMD3<Float>(0, 1, 0)
    }
}
