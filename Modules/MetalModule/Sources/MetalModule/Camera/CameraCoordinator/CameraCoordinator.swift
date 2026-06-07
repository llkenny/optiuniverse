//
//  CameraCoordinator.swift
//  MetalModule
//
//  Created by max on 22.05.2026.
//

import CoreFoundation
import CoreGraphics
import Foundation
import simd

/// Routes camera commands to the active camera mode owners.
///
/// `CameraCoordinator` is the camera-layer entry point used by UI gestures, navigation, transfer
/// preview, and the renderer frame loop. It owns mode priority and lifecycle routing, then delegates
/// mode-specific math to owners/modes that commit `CameraState.Transaction` values.
///
/// ADR 0003 boundary:
/// - UI and feature controllers call this coordinator instead of mutating renderer camera fields.
/// - Follow, navigation, transfer preview, orbit, zoom, and trajectory behavior stay in camera modes.
/// - `SnapshotProvider` derives render-ready matrices from committed `CameraState`; the coordinator
///   only refreshes derived state needed by the current mode before snapshots are requested.
@MainActor
final class CameraCoordinator {

    // MARK: Constants
    private let orbitSpeed: Float = 0.01

    private let cameraState: CameraState
    private unowned let snapshotProvider: SnapshotProvider

    private let zoomMode: ZoomCameraMode
    private let orbitMode: OrbitCameraMode
    private let trajectoryMode: TrajectoryCameraMode
    let followCameraOwner: FollowCameraOwner
    let navigationCameraOwner: NavigationCameraOwner
    let transferPreviewCameraOwner: TransferPreviewCameraOwner

    private var activeCameraMotionRevision = 0

    var currentCameraTransitionFrame: CameraTransition.Frame {
        cameraState.currentCameraTransitionFrame
    }

    var currentCameraPose: CameraPose {
        cameraState.pose
    }

    var cameraFollowTransitionDuration: Float {
        cameraState.cameraFollowTransitionDuration
    }

    var cameraTarget: SIMD3<Float> {
        cameraState.cameraTarget
    }

    var cameraDistance: Float {
        cameraState.cameraDistance
    }

    init(cameraState: CameraState,
         snapshotProvider: SnapshotProvider) {
        self.cameraState = cameraState
        self.snapshotProvider = snapshotProvider
        zoomMode = .init()
        orbitMode = .init()
        trajectoryMode = .init()
        followCameraOwner = .init(cameraState: cameraState,
                                  snapshotProvider: snapshotProvider)
        navigationCameraOwner = .init(cameraState: cameraState)
        transferPreviewCameraOwner = .init(cameraState: cameraState)
    }

    func makeTranslation(with value: CGPoint,
                         viewportSize: CGSize) {
        guard viewportSize.width.isFinite,
              viewportSize.height.isFinite,
              viewportSize.width > 0,
              viewportSize.height > 0 else {
            return
        }

        let camera = TrajectoryCameraMode.CameraInput(distance: cameraState.cameraDistance,
                                                      orientation: cameraState.cameraOrientation,
                                                      target: cameraState.cameraTarget)
        commitManualCameraTransaction(
            trajectoryMode.makePanTransaction(translation: value,
                                              viewportSize: viewportSize,
                                              camera: camera)
        )
    }

    func makeRotation(with value: CGPoint, velocity: CGPoint) {
        commitManualCameraTransaction(
            orbitMode.makeOrbitTransaction(horizontal: Float(value.x) * orbitSpeed,
                                           vertical: -Float(value.y) * orbitSpeed,
                                           cameraOrientation: cameraState.cameraOrientation)
        )
        orbitMode.addInertia(velocity: velocity)
    }

    func makeScale(with value: Float, velocity: CGFloat) {
        commitManualCameraTransaction(
            zoomMode.makeZoomTransaction(value: value,
                                         currentDistance: cameraState.cameraDistance)
        )
        zoomMode.addInertia(velocity: velocity,
                            currentDistance: cameraState.cameraDistance)
    }

    func followPlanet(named name: String,
                      surfaceCoordinate: SurfaceCoordinate? = nil,
                      viewportSize: CGSize) {
        followCameraOwner.followPlanet(named: name,
                                       surfaceCoordinate: surfaceCoordinate,
                                       viewportSize: viewportSize)
        refreshCamera()
    }

    func followNavigationDestination(named name: String,
                                     viewportSize: CGSize) {
        followCameraOwner.followPlanet(named: name,
                                       viewportSize: viewportSize)
        refreshCamera()
    }

    func beginManualCameraControl() {
        zoomMode.cancelInertia()
        orbitMode.cancelInertia()
        followCameraOwner.beginManualCameraControl()
    }

    /// Advances all camera-layer per-frame work for the current render iteration.
    ///
    /// Route playback and transfer-orbit geometry remain owned by their controllers. This entry point
    /// owns camera priority for manual inertia and follow behavior before `SnapshotProvider` derives
    /// immutable matrices.
    func updateFrameCamera(snapshot: PreparedRenderSnapshot?,
                           delta: Float,
                           viewportSize: CGSize,
                           modeState: CameraFrameModeState) {
        updateManualCameraInertia(delta: delta)

        let isSuppressed = modeState.navigationControlsCamera || modeState.transferPreviewActive
        followCameraOwner.update(snapshot: snapshot,
                                 delta: delta,
                                 viewportSize: viewportSize,
                                 isSuppressed: isSuppressed)
        if !isSuppressed {
            refreshCamera(snapshot: snapshot)
        }

        if hasActiveCameraMotion(modeState: modeState) {
            activeCameraMotionRevision += 1
        }
    }

    func followProjectionParameters(snapshot: PreparedRenderSnapshot?,
                                    baseProjection: CameraProjectionParameters) -> CameraProjectionParameters {
        followCameraOwner.projectionParameters(snapshot: snapshot,
                                               baseProjection: baseProjection)
    }

    func makeSnapshotDependencies(snapshot: PreparedRenderSnapshot?,
                                  viewportSize: CGSize,
                                  projection: CameraProjectionParameters,
                                  modeState: CameraFrameModeState) -> CameraSnapshotDependencies {
        CameraSnapshotDependencies(
            followedObject: followCameraOwner.snapshotDependency(snapshot: snapshot),
            navigation: modeState.navigation,
            transfer: modeState.transfer,
            activeCameraMotionRevision: activeCameraMotionRevision,
            sceneFrameID: snapshot?.frameID,
            viewportSize: viewportSize,
            projection: projection
        )
    }

    /// Rebuilds derived camera values after mode transactions or gesture inertia.
    ///
    /// This replaces the old renderer-owned `updateCamera()` path while keeping matrix derivation
    /// centralized in `CameraState`/`SnapshotProvider`.
    func refreshCamera(snapshot: PreparedRenderSnapshot? = nil) {
        let snapshot = snapshot ?? snapshotProvider.latestSnapshot
        cameraState.enforceCameraConstraints(
            minDistance: followCameraOwner.minimumAllowedCameraDistance(snapshot: snapshot)
        )
    }

    private func updateManualCameraInertia(delta: Float) {
        commitManualCameraTransaction(
            zoomMode.update(delta: delta,
                            currentDistance: cameraState.cameraDistance)
        )
        commitManualCameraTransaction(
            orbitMode.update(delta: delta,
                             cameraOrientation: cameraState.cameraOrientation)
        )

        if !isNavigationCameraActive {
            refreshCamera()
        }
    }

    private func hasActiveCameraMotion(modeState: CameraFrameModeState) -> Bool {
        zoomMode.hasActiveInertia ||
        orbitMode.hasActiveInertia ||
        followCameraOwner.hasActiveTransition ||
        modeState.hasActiveExternalCameraMotion
    }

    private func commitManualCameraTransaction(_ transaction: CameraState.Transaction?) {
        guard let transaction else { return }
        cameraState.commit(transaction)
    }
}
