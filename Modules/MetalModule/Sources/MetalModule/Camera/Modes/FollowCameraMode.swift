//
//  FollowCameraMode.swift
//  MetalModule
//
//  Created by Codex on 29.05.2026.
//

import CoreGraphics
import simd

/// Computes camera transactions for the current planet-follow behavior.
final class FollowCameraMode {
    func makeSteadyFollowTransaction(named name: String,
                                     snapshot: PreparedRenderSnapshot) -> CameraState.Transaction? {
        guard let position = snapshot.worldPosition(ofPlanetNamed: name) else {
            return nil
        }

        return CameraState.Transaction(cameraTarget: position)
    }

    func makeTransitionFrame(named name: String,
                             snapshot: PreparedRenderSnapshot,
                             currentDistance: Float,
                             viewportSize: CGSize) -> CameraTransition.Frame? {
        guard let position = snapshot.worldPosition(ofPlanetNamed: name),
              let framingRadius = snapshot.framingRadius(ofPlanetNamed: name) else {
            return nil
        }

        return CameraTransition.Frame(
            target: position,
            distance: CameraFit.distanceToFit(radius: framingRadius,
                                              currentDistance: currentDistance,
                                              viewportSize: viewportSize)
        )
    }

    func makeTransitionTransaction(frame: CameraTransition.Frame,
                                   cameraOrientation: simd_quatf) -> CameraState.Transaction {
        let orientation = simd_normalize(cameraOrientation)
        let cameraOffset = orientation.act(SIMD3<Float>(0, 0, frame.distance))
        let cameraPosition = cameraOffset + frame.target
        let cameraUp = orientation.act(SIMD3<Float>(0, 1, 0))

        return CameraState.Transaction(cameraTarget: frame.target,
                                       cameraPosition: cameraPosition,
                                       cameraDistance: frame.distance,
                                       cameraUp: cameraUp,
                                       cameraOffset: cameraOffset,
                                       cameraOrientation: orientation)
    }

    func minimumDistance(followingPlanetName: String?,
                         snapshot: PreparedRenderSnapshot?,
                         baseMinimumDistance: Float) -> Float {
        guard let followingPlanetName,
              let framingRadius = snapshot?.framingRadius(ofPlanetNamed: followingPlanetName) else {
            return baseMinimumDistance
        }

        return max(baseMinimumDistance, framingRadius * 1.05)
    }

    func projectionParameters(followingPlanetName: String?,
                              snapshot: PreparedRenderSnapshot?,
                              cameraDistance: Float,
                              baseProjection: CameraProjectionParameters) -> CameraProjectionParameters {
        guard let followingPlanetName else {
            return baseProjection
        }

        let framingRadius = snapshot?.framingRadius(ofPlanetNamed: followingPlanetName)
        return CameraProjectionParameters(
            nearPlane: CameraFit.nearPlaneDistance(cameraDistance: cameraDistance,
                                                   framingRadius: framingRadius),
            farPlane: baseProjection.farPlane
        )
    }
}
