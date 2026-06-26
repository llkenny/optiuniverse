//
//  ImmersiveTransferOverviewState.swift
//  UniverseModule
//
//  Created by Codex on 26.06.2026.
//

import simd

/// Presents a camera-framed transfer overview in a head-tracked immersive space.
///
/// visionOS does not use the module's virtual camera as the user's viewpoint, so this state maps
/// the camera pose into a transform for the entire installed universe instead.
struct ImmersiveTransferOverviewState {
    private static let minimumCameraDistance: Float = 0.0001

    private(set) var isActive = false
    private(set) var persistedTransform: float4x4?

    var hasPersistedTransform: Bool {
        persistedTransform != nil
    }

    mutating func begin() {
        isActive = true
        persistedTransform = nil
    }

    mutating func persist(cameraPose: CameraPose,
                          targetAfterSceneOrigin: SIMD3<Float>) -> float4x4? {
        guard isActive,
              cameraPose.distance.isFinite,
              cameraPose.distance > Self.minimumCameraDistance else {
            return persistedTransform
        }

        let anchorDistance = simd_length(ImmersiveFocusState.targetCenter)
        let overviewScale = anchorDistance / cameraPose.distance
        let transform = float4x4.makeTranslation(ImmersiveFocusState.targetCenter)
            * float4x4.makeScale(SIMD3<Float>(repeating: overviewScale))
            * float4x4(cameraPose.orientation.inverse)
            * float4x4.makeTranslation(-targetAfterSceneOrigin)
        persistedTransform = transform
        return transform
    }

    mutating func clear() {
        isActive = false
        persistedTransform = nil
    }
}
