//
//  TransferPreviewCameraCoordinating.swift
//  UniverseModule
//
//  Created by Codex on 28.05.2026.
//

import simd

@MainActor
protocol TransferPreviewCameraCoordinating: AnyObject {
    var currentCameraTransitionFrame: CameraTransition.Frame { get }
    var cameraFollowTransitionDuration: Float { get }
    var cameraTarget: SIMD3<Float> { get }
    var cameraDistance: Float { get }

    func commitTransferPreviewTransition(frame: CameraTransition.Frame)
}
