//
//  CameraFrameModeState.swift
//  UniverseModule
//
//  Created by max on 31.05.2026.
//

struct CameraFrameModeState: Equatable {
    let transferPreviewActive: Bool
    let transfer: CameraTransferSnapshotDependency?

    var hasActiveExternalCameraMotion: Bool {
        transfer?.hasActiveTransition == true
    }
}
