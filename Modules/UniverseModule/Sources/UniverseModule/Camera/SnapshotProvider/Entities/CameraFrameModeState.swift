//
//  CameraFrameModeState.swift
//  UniverseModule
//
//  Created by max on 31.05.2026.
//

struct CameraFrameModeState: Equatable {
    let navigationControlsCamera: Bool
    let navigation: CameraNavigationSnapshotDependency?
    let transferPreviewActive: Bool
    let transfer: CameraTransferSnapshotDependency?

    var hasActiveExternalCameraMotion: Bool {
        navigation?.hasActiveTransition == true ||
        transfer?.hasActiveTransition == true
    }
}
