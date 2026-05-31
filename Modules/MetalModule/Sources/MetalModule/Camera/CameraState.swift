//
//  CameraState.swift
//  MetalModule
//
//  Created by max on 20.05.2026.
//

import simd

struct CameraPose: Equatable {
    let target: SIMD3<Float>
    let distance: Float
    let orientation: simd_quatf

    var offset: SIMD3<Float> {
        orientation.act(SIMD3<Float>(0, 0, distance))
    }

    var position: SIMD3<Float> {
        target + offset
    }

    var upVector: SIMD3<Float> {
        orientation.act(SIMD3<Float>(0, 1, 0))
    }

    var transitionFrame: CameraTransition.Frame {
        .init(target: target,
              distance: distance)
    }

    func makeRenderViewMatrix() -> float4x4 {
        float4x4.lookAt(
            eye: offset,
            target: .zero,
            upVector: upVector
        )
    }
}

/// Owns canonical camera variables and camera revision metadata
final class CameraState {
    struct DirtyFields: OptionSet, Equatable {
        let rawValue: Int

        static let target = DirtyFields(rawValue: 1 << 0)
        static let distance = DirtyFields(rawValue: 1 << 1)
        static let orientation = DirtyFields(rawValue: 1 << 2)
    }

    struct Transaction {
        var cameraTarget: SIMD3<Float>?
        var cameraDistance: Float?
        var cameraOrientation: simd_quatf?

        init(cameraTarget: SIMD3<Float>? = nil,
             cameraDistance: Float? = nil,
             cameraOrientation: simd_quatf? = nil) {
            self.cameraTarget = cameraTarget
            self.cameraDistance = cameraDistance
            self.cameraOrientation = cameraOrientation
        }
    }

    let cameraFollowTransitionDuration: Float = 1.1

    let minDistance: Float = 0.001
    private let maxDistance: Float = 10000.0

    private(set) var cameraDistance: Float = 3 // !
    private(set) var cameraTarget = SIMD3<Float>(0, 0, 0) // !
    private(set) var cameraOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)) // !
    private(set) var revision = 0
    private(set) var lastDirtyFields: DirtyFields = []

    var pose: CameraPose {
        CameraPose(target: cameraTarget,
                   distance: cameraDistance,
                   orientation: cameraOrientation)
    }

    var currentCameraTransitionFrame: CameraTransition.Frame {
        pose.transitionFrame
    }

    @discardableResult
    func commit(_ transaction: Transaction) -> DirtyFields {
        var dirtyFields: DirtyFields = []

        if let cameraTarget = transaction.cameraTarget {
            if self.cameraTarget != cameraTarget {
                self.cameraTarget = cameraTarget
                dirtyFields.insert(.target)
            }
        }
        if let cameraDistance = transaction.cameraDistance {
            if self.cameraDistance != cameraDistance {
                self.cameraDistance = cameraDistance
                dirtyFields.insert(.distance)
            }
        }
        if let cameraOrientation = transaction.cameraOrientation {
            let normalizedOrientation = simd_normalize(cameraOrientation)
            if self.cameraOrientation != normalizedOrientation {
                self.cameraOrientation = normalizedOrientation
                dirtyFields.insert(.orientation)
            }
        }

        guard !dirtyFields.isEmpty else {
            return []
        }
        lastDirtyFields = dirtyFields
        revision += 1
        return dirtyFields
    }

    /// Keeps zoom inside available range and outside of the followed planet
    /// - Parameter minDistance: Minimum allowed camera distance
    @discardableResult
    func enforceCameraConstraints(minDistance: Float) -> DirtyFields {
        let distance = cameraDistance
        let fixedDistance = max(minDistance, min(distance, maxDistance))
        guard fixedDistance != distance else { return [] }

        return commit(Transaction(cameraDistance: fixedDistance))
    }
}
