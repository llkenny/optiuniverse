//
//  TransferPreviewCameraOwner.swift
//  MetalModule
//
//  Created by Codex on 28.05.2026.
//

import simd

@MainActor
final class TransferPreviewCameraOwner {
    private unowned let cameraState: CameraState

    init(cameraState: CameraState) {
        self.cameraState = cameraState
    }

    func commitTransition(frame: CameraTransition.Frame) {
        let cameraOrientation = simd_normalize(cameraState.cameraOrientation)

        cameraState.commit(CameraState.Transaction(cameraTarget: frame.target,
                                                   cameraDistance: frame.distance,
                                                   cameraOrientation: cameraOrientation))
    }
}
