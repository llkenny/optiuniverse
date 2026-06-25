//
//  FollowCameraMode.swift
//  UniverseModule
//
//  Created by Codex on 29.05.2026.
//

import CoreGraphics
import simd

/// Computes transactions for the current planet-follow camera mode.
///
/// This type is intentionally stateless. `FollowCameraOwner` stores the selected planet, pending
/// requests, and transition lifecycle; `FollowCameraMode` only translates a prepared scene snapshot,
/// viewport, and current camera values into transaction-ready camera data.
///
/// The mode preserves the existing follow behavior:
/// - smoothly transition to a selected planet using its framing radius
/// - keep the camera target locked to the followed planet as simulation time advances
/// - tighten minimum distance and near plane around the followed planet
final class FollowCameraMode {
    /// Returns the per-frame target update for a followed planet.
    func makeSteadyFollowTransaction(named name: String,
                                     snapshot: UniverseSceneSnapshot) -> CameraState.Transaction? {
        guard let position = snapshot.worldPosition(ofPlanetNamed: name) else {
            return nil
        }

        return CameraState.Transaction(cameraTarget: position)
    }

    /// Resolves a transition destination for a planet follow animation.
    func makeTransitionFrame(named name: String,
                             snapshot: UniverseSceneSnapshot,
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

    /// Converts an eased transition frame into canonical camera variables.
    func makeTransitionTransaction(frame: CameraTransition.Frame,
                                   cameraOrientation: simd_quatf) -> CameraState.Transaction {
        let orientation = simd_normalize(cameraOrientation)

        return CameraState.Transaction(cameraTarget: frame.target,
                                       cameraDistance: frame.distance,
                                       cameraOrientation: orientation)
    }

    /// Keeps zoom outside the followed planet's visual radius.
    func minimumDistance(followingPlanetName: String?,
                         snapshot: UniverseSceneSnapshot?,
                         baseMinimumDistance: Float) -> Float {
        guard let followingPlanetName,
              let framingRadius = snapshot?.framingRadius(ofPlanetNamed: followingPlanetName) else {
            return baseMinimumDistance
        }

        return max(baseMinimumDistance, framingRadius * 1.05)
    }

    /// Applies follow-specific near-plane policy while preserving the caller's far plane.
    func projectionParameters(followingPlanetName: String?,
                              snapshot: UniverseSceneSnapshot?,
                              cameraDistance: Float,
                              baseProjection: CameraProjectionParameters) -> CameraProjectionParameters {
        guard let followingPlanetName else {
            return baseProjection
        }

        let framingRadius = snapshot?.framingRadius(ofPlanetNamed: followingPlanetName)
        return baseProjection.withClippingPlanes(
            nearPlane: CameraFit.nearPlaneDistance(cameraDistance: cameraDistance,
                                                   framingRadius: framingRadius)
        )
    }
}
