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
        cameraState.normalizeCameraOrientation()
        let cameraOffset = cameraState.cameraOrientation.act(SIMD3<Float>(0, 0, frame.distance))
        let cameraPosition = cameraOffset + frame.target
        let cameraUp = cameraState.cameraOrientation.act(SIMD3<Float>(0, 1, 0))

        cameraState.commit(CameraState.Transaction(cameraTarget: frame.target,
                                                   cameraPosition: cameraPosition,
                                                   cameraDistance: frame.distance,
                                                   cameraUp: cameraUp,
                                                   cameraOffset: cameraOffset))
    }
}
