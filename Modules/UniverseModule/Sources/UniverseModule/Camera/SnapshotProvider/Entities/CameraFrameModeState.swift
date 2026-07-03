//
//  CameraFrameModeState.swift
//  UniverseModule
//
//  Created by max on 31.05.2026.
//

struct CameraFrameModeState: Equatable {
    let transferPreviewActive: Bool
    let transfer: CameraTransferSnapshotDependency?
    let navigation: NavigationRouteRenderState

    init(transferPreviewActive: Bool,
         transfer: CameraTransferSnapshotDependency?,
         navigation: NavigationRouteRenderState = .idle) {
        self.transferPreviewActive = transferPreviewActive
        self.transfer = transfer
        self.navigation = navigation
    }

    var navigationActive: Bool {
        navigation.route != nil
    }

    var hasActiveExternalCameraMotion: Bool {
        transfer?.hasActiveTransition == true || navigationActive
    }
}
