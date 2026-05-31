//
//  MetalRenderer+CameraFrame.swift
//  MetalModule
//
//  Created by Codex on 31.05.2026.
//

extension MetalRenderer {
    func makeCameraFrameModeState() -> CameraFrameModeState {
        CameraFrameModeState(
            navigationControlsCamera: navigationController.controlsCamera,
            navigation: navigationController.cameraSnapshotDependency,
            transferPreviewActive: transferOrbitController.isTransferPreviewActive,
            transfer: transferOrbitController.cameraSnapshotDependency
        )
    }

    func makeCameraProjection(snapshot: PreparedRenderSnapshot?,
                              objectInfoOverlayAdjustment: ObjectInfoOverlayFramingState.ProjectionAdjustment)
    -> CameraProjectionParameters {
        let baseProjection = CameraProjectionParameters(
            nearPlane: CameraFit.defaultNearPlane,
            farPlane: farPlaneDistance(),
            verticalFieldOfView: objectInfoOverlayAdjustment.verticalFieldOfView,
            verticalCenterOffset: objectInfoOverlayAdjustment.verticalCenterOffset
        )
        let followProjection = cameraCoordinator.followProjectionParameters(snapshot: snapshot,
                                                                            baseProjection: baseProjection)
        let transferProjection = transferOrbitController.projectionParameters(snapshot: snapshot,
                                                                             baseProjection: followProjection)
        return navigationController.projectionParameters(snapshot: snapshot,
                                                        baseProjection: transferProjection)
    }

    func makeCameraSnapshot(snapshot: PreparedRenderSnapshot?,
                            projection: CameraProjectionParameters,
                            modeState: CameraFrameModeState) -> SnapshotProvider.CameraSnapshot {
        let dependencies = cameraCoordinator.makeSnapshotDependencies(
            snapshot: snapshot,
            viewportSize: metalView.bounds.size,
            projection: projection,
            modeState: modeState
        )
        return snapshotProvider.makeCameraSnapshot(dependencies: dependencies)
    }
}
