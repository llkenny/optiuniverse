//
//  CameraState.swift
//  MetalModule
//
//  Created by max on 20.05.2026.
//

import simd

/// Owns canonical camera variables and camera revision metadata
final class CameraState {
    struct Transaction {
        var cameraTarget: SIMD3<Float>?
        var cameraPosition: SIMD3<Float>?
        var cameraDistance: Float?
        var cameraUp: SIMD3<Float>?
        var cameraOffset: SIMD3<Float>?
        var cameraOrientation: simd_quatf?

        init(cameraTarget: SIMD3<Float>? = nil,
             cameraPosition: SIMD3<Float>? = nil,
             cameraDistance: Float? = nil,
             cameraUp: SIMD3<Float>? = nil,
             cameraOffset: SIMD3<Float>? = nil,
             cameraOrientation: simd_quatf? = nil) {
            self.cameraTarget = cameraTarget
            self.cameraPosition = cameraPosition
            self.cameraDistance = cameraDistance
            self.cameraUp = cameraUp
            self.cameraOffset = cameraOffset
            self.cameraOrientation = cameraOrientation
        }
    }

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
    private(set) var revision = 0

    var currentCameraTransitionFrame: CameraTransition.Frame {
        .init(target: cameraTarget,
              distance: cameraDistance)
    }

    func commit(_ transaction: Transaction) {
        if let cameraTarget = transaction.cameraTarget {
            self.cameraTarget = cameraTarget
        }
        if let cameraPosition = transaction.cameraPosition {
            self.cameraPosition = cameraPosition
        }
        if let cameraDistance = transaction.cameraDistance {
            self.cameraDistance = cameraDistance
        }
        if let cameraUp = transaction.cameraUp {
            self.cameraUp = cameraUp
        }
        if let cameraOffset = transaction.cameraOffset {
            self.cameraOffset = cameraOffset
        }
        if let cameraOrientation = transaction.cameraOrientation {
            self.cameraOrientation = simd_normalize(cameraOrientation)
        }
        revision += 1
    }

    // MARK: Common

    private func normalizeCameraOrientation() {
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
    private func checkDistance(minDistance: Float) {
        let distance = cameraDistance
        let fixedDinstance = max(minDistance, min(distance, maxDistance))
        guard fixedDinstance != distance else { return }

        commit(Transaction(cameraDistance: fixedDinstance))
    }

    @discardableResult
    func refreshDerivedCameraValues(minDistance: Float) -> float4x4 {
        checkDistance(minDistance: minDistance)
        return makeViewMatrix()
    }

    func makeRenderViewMatrix() -> float4x4 {
        float4x4.lookAt(
            eye: cameraOffset,
            target: .zero,
            upVector: cameraUp
        )
    }
}
