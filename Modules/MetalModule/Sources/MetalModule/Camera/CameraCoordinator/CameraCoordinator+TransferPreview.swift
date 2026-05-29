//
//  CameraCoordinator+TransferPreview.swift
//  MetalModule
//
//  Created by Codex on 28.05.2026.
//

extension CameraCoordinator: TransferPreviewCameraCoordinating {
    func commitTransferPreviewTransition(frame: CameraTransition.Frame) {
        transferPreviewCameraOwner.commitTransition(frame: frame)
    }
}
