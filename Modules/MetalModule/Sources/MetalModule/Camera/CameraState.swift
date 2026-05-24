//
//  CameraState.swift
//  MetalModule
//
//  Created by max on 20.05.2026.
//

import simd

/// Owns canonical camera variables and camera revision metadata
final class CameraState {

    let cameraFollowTransitionDuration: Float = 1.1

    let minDistance: Float = 0.001
    private let maxDistance: Float = 10000.0

    private(set) var cameraDistance: Float = 3 // !
    private(set) var cameraTarget = SIMD3<Float>(0, 0, 0) // !

    private(set) var cameraOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)) // !

    /// Derivatives
    /// Derived values such as camera position, offset, up vector, view matrix,
    /// and projection matrix should generally belong to immutable snapshots instead of being
    /// independently mutable state.
    /// This reduces stale or contradictory camera data.
    private(set) var cameraPosition = SIMD3<Float>(0, 0, 0)
    private(set) var cameraUp = SIMD3<Float>(0, 1, 0)
    private(set) var cameraOffset = SIMD3<Float>(0, 0, 3)

    var currentCameraTransitionFrame: CameraTransition.Frame {
        .init(target: cameraTarget,
              distance: cameraDistance)
    }

    // MARK: Setters

    func set(cameraTarget: SIMD3<Float>) {
        self.cameraTarget = cameraTarget
    }

    func set(cameraPosition: SIMD3<Float>) {
        self.cameraPosition = cameraPosition
    }

    // MARK: Derivatives
    func set(cameraDistance: Float) {
        self.cameraDistance = cameraDistance
    }

    func set(cameraUp: SIMD3<Float>) {
        self.cameraUp = cameraUp
    }

    func set(cameraOffset: SIMD3<Float>) {
        self.cameraOffset = cameraOffset
    }

    // Probable deriative too
    func set(cameraOrientation: simd_quatf) {
        self.cameraOrientation = cameraOrientation
    }

    // MARK: Common

    func normalizeCameraOrientation() {
        cameraOrientation = simd_normalize(cameraOrientation)
    }

    func makeViewMatrix() -> float4x4 {
        normalizeCameraOrientation()

        cameraOffset = cameraOrientation.act(SIMD3<Float>(0, 0, cameraDistance))
        // looks loke cameraPosition, cameraOffset and cameraUp is no sense to change outside of the class
        // cameraTarget is resetted each frame while following a planet
        cameraPosition = cameraOffset + cameraTarget
        cameraUp = cameraOrientation.act(SIMD3<Float>(0, 1, 0))

        // Conslusion:
        // only cameraOrientation persists after each frame MetalRenderer updates
        // All other changes, probably, dead

        return float4x4.lookAt(
            eye: cameraPosition,
            target: cameraTarget,
            upVector: cameraUp
        )
    }

    /// Keeps zoom inside available range and outside of the followed planet
    /// - Parameter minDistance: Minimum allowed camera distance
    func checkDistance(minDistance: Float) {
        let distance = cameraDistance
        let fixedDinstance = max(minDistance, min(distance, maxDistance))
        set(cameraDistance: fixedDinstance)
    }

    func makeRenderViewMatrix() -> float4x4 {
        float4x4.lookAt(
            eye: cameraOffset,
            target: .zero,
            upVector: cameraUp
        )
    }
}
