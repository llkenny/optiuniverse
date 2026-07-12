//
//  CameraCoordinator.swift
//  UniverseModule
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
/// - Follow, transfer preview, orbit, zoom, and trajectory behavior stay in camera modes.
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
    private let navigationCameraMode: NavigationCameraMode
    let followCameraOwner: FollowCameraOwner
    let transferPreviewCameraOwner: TransferPreviewCameraOwner

    private var activeCameraMotionRevision = 0
    private var navigationArrivalRecovery: NavigationArrivalRecovery?
    private var manualNavigationPivot: ManualNavigationPivot?

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
        navigationCameraMode = .init()
        followCameraOwner = .init(cameraState: cameraState,
                                  snapshotProvider: snapshotProvider)
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

    func adoptNavigationDestination(named name: String) {
        followCameraOwner.adoptPlanet(named: name)
        refreshCamera()
    }

    func beginManualCameraControl() {
        navigationArrivalRecovery = nil
        zoomMode.cancelInertia()
        orbitMode.cancelInertia()
        followCameraOwner.beginManualCameraControl()
    }

    func handOffNavigationCameraControl(navigation: NavigationRouteRenderState,
                                        snapshot: UniverseSceneSnapshot?,
                                        viewportSize: CGSize) {
        guard let route = navigation.route,
              let marker = route.point(at: navigation.progress) else {
            manualNavigationPivot = nil
            return
        }

        guard navigation.isCameraAutoFramingEnabled else {
            updateManualNavigationPivot(route: route,
                                        marker: marker)
            return
        }

        let modeState = CameraFrameModeState(
            transferPreviewActive: false,
            transfer: nil,
            navigation: navigation
        )
        commitNavigationCameraTransaction(snapshot: snapshot,
                                          viewportSize: viewportSize,
                                          modeState: modeState)
        refreshCamera(snapshot: snapshot,
                      maximumDistance: maximumCameraDistance(modeState: modeState,
                                                             viewportSize: viewportSize),
                      minimumDistance: minimumCameraDistance(snapshot: snapshot,
                                                             modeState: modeState))
        manualNavigationPivot = ManualNavigationPivot(routeID: route.id,
                                                      marker: marker)
    }

    /// Advances all camera-layer per-frame work for the current render iteration.
    ///
    /// Route playback and transfer-orbit geometry remain owned by their controllers. This entry point
    /// owns camera priority for manual inertia and follow behavior before `SnapshotProvider` derives
    /// immutable matrices.
    func updateFrameCamera(snapshot: UniverseSceneSnapshot?,
                           delta: Float,
                           viewportSize: CGSize,
                           modeState: CameraFrameModeState) {
        updateManualNavigationPivot(navigation: modeState.navigation)
        updateManualCameraInertia(delta: delta)

        let isSuppressed = modeState.transferPreviewActive || modeState.navigationActive
        followCameraOwner.update(snapshot: snapshot,
                                 delta: delta,
                                 viewportSize: viewportSize,
                                 isSuppressed: isSuppressed)

        commitNavigationCameraTransaction(snapshot: snapshot,
                                          viewportSize: viewportSize,
                                          modeState: modeState)

        if !isSuppressed || modeState.transferPreviewActive || modeState.navigationActive {
            refreshCamera(snapshot: snapshot,
                          maximumDistance: maximumCameraDistance(modeState: modeState,
                                                                 viewportSize: viewportSize),
                          minimumDistance: minimumCameraDistance(snapshot: snapshot,
                                                                 modeState: modeState))
        }

        if hasActiveCameraMotion(modeState: modeState) {
            activeCameraMotionRevision += 1
        }
    }

    func followProjectionParameters(snapshot: UniverseSceneSnapshot?,
                                    baseProjection: CameraProjectionParameters) -> CameraProjectionParameters {
        followCameraOwner.projectionParameters(snapshot: snapshot,
                                               baseProjection: baseProjection)
    }

    func navigationProjectionParameters(modeState: CameraFrameModeState,
                                        baseProjection: CameraProjectionParameters) -> CameraProjectionParameters {
        navigationCameraMode.projectionParameters(state: modeState.navigation,
                                                  cameraDistance: cameraState.cameraDistance,
                                                  baseProjection: baseProjection)
    }

    func makeSnapshotDependencies(snapshot: UniverseSceneSnapshot?,
                                  viewportSize: CGSize,
                                  projection: CameraProjectionParameters,
                                  modeState: CameraFrameModeState) -> CameraSnapshotDependencies {
        CameraSnapshotDependencies(
            followedObject: followCameraOwner.snapshotDependency(snapshot: snapshot),
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
    func refreshCamera(snapshot: UniverseSceneSnapshot? = nil,
                       maximumDistance: Float? = nil,
                       minimumDistance: Float? = nil) {
        let snapshot = snapshot ?? snapshotProvider.latestSnapshot
        let resolvedMinimumDistance = minimumDistance ??
            followCameraOwner.minimumAllowedCameraDistance(snapshot: snapshot)
        cameraState.enforceCameraConstraints(
            minDistance: resolvedMinimumDistance,
            maximumDistance: maximumDistance
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

    }

    private func hasActiveCameraMotion(modeState: CameraFrameModeState) -> Bool {
        zoomMode.hasActiveInertia ||
        orbitMode.hasActiveInertia ||
        followCameraOwner.hasActiveTransition ||
        modeState.hasActiveExternalCameraMotion
    }

    private func commitManualCameraTransaction(_ transaction: CameraState.Transaction?) {
        guard let transaction else { return }
        cameraState.commit(manualNavigationPivotTransaction(for: transaction) ?? transaction)
    }

    private func commitNavigationCameraTransaction(snapshot: UniverseSceneSnapshot?,
                                                   viewportSize: CGSize,
                                                   modeState: CameraFrameModeState) {
        guard !modeState.transferPreviewActive else {
            navigationArrivalRecovery = nil
            manualNavigationPivot = nil
            return
        }
        guard let route = modeState.navigation.route else {
            navigationArrivalRecovery = nil
            manualNavigationPivot = nil
            return
        }
        if manualNavigationPivot?.routeID != route.id {
            manualNavigationPivot = nil
        }
        guard modeState.navigation.isCameraAutoFramingEnabled ||
              navigationCameraMode.isArrivalPhase(state: modeState.navigation) else {
            return
        }

        let arrivalRecovery = navigationArrivalRecovery(
            routeID: route.id,
            modeState: modeState
        )

        let transaction = navigationCameraMode.makeNavigationTransaction(
            state: modeState.navigation,
            snapshot: snapshot,
            viewportSize: viewportSize,
            currentPose: cameraState.pose,
            arrivalRecovery: arrivalRecovery
        )
        guard let transaction else { return }

        cameraState.commit(transaction)
    }

    private func navigationArrivalRecovery(routeID: UUID,
                                           modeState: CameraFrameModeState) -> NavigationCameraMode.ArrivalRecovery? {
        guard !modeState.navigation.isCameraAutoFramingEnabled,
              navigationCameraMode.isArrivalPhase(state: modeState.navigation) else {
            navigationArrivalRecovery = nil
            return nil
        }

        if navigationArrivalRecovery?.routeID != routeID {
            navigationArrivalRecovery = NavigationArrivalRecovery(
                routeID: routeID,
                recovery: NavigationCameraMode.ArrivalRecovery(
                    startFrame: cameraState.currentCameraTransitionFrame,
                    startProgress: modeState.navigation.progress
                )
            )
        }

        return navigationArrivalRecovery?.recovery
    }

    private func maximumCameraDistance(modeState: CameraFrameModeState,
                                       viewportSize: CGSize) -> Float? {
        modeState.transfer?.maximumCameraDistance ??
        navigationCameraMode.maximumCameraDistance(state: modeState.navigation,
                                                   currentDistance: cameraState.cameraDistance,
                                                   viewportSize: viewportSize)
    }

    private func minimumCameraDistance(snapshot: UniverseSceneSnapshot?,
                                       modeState: CameraFrameModeState) -> Float? {
        guard !modeState.transferPreviewActive,
              modeState.navigationActive else {
            return nil
        }

        return navigationCameraMode.minimumCameraDistance(
            state: modeState.navigation,
            snapshot: snapshot,
            baseMinimumDistance: cameraState.minDistance
        )
    }

    private func manualNavigationPivotTransaction(for transaction: CameraState.Transaction)
    -> CameraState.Transaction? {
        guard let manualNavigationPivot else {
            return nil
        }
        guard transaction.cameraTarget == nil else {
            self.manualNavigationPivot = nil
            return nil
        }

        let currentPose = cameraState.pose
        let newDistance = transaction.cameraDistance ?? currentPose.distance
        guard newDistance.isFinite,
              newDistance > Self.manualNavigationPivotEpsilon,
              currentPose.distance > Self.manualNavigationPivotEpsilon else {
            return nil
        }

        let newOrientation = transaction.cameraOrientation ?? currentPose.orientation
        var markerToCamera = currentPose.position - manualNavigationPivot.marker

        if transaction.cameraOrientation != nil {
            let orientationDelta = simd_normalize(newOrientation * currentPose.orientation.inverse)
            markerToCamera = orientationDelta.act(markerToCamera)
        }
        if transaction.cameraDistance != nil {
            markerToCamera *= newDistance / currentPose.distance
        }

        let newCameraPosition = manualNavigationPivot.marker + markerToCamera
        let newCameraTarget = newCameraPosition - newOrientation.act(SIMD3<Float>(0, 0, newDistance))
        return CameraState.Transaction(cameraTarget: newCameraTarget,
                                       cameraDistance: transaction.cameraDistance,
                                       cameraOrientation: transaction.cameraOrientation)
    }

    private func updateManualNavigationPivot(navigation: NavigationRouteRenderState) {
        guard let route = navigation.route,
              let marker = route.point(at: navigation.progress) else {
            manualNavigationPivot = nil
            return
        }

        updateManualNavigationPivot(route: route,
                                    marker: marker)
    }

    private func updateManualNavigationPivot(route: NavigationRoute,
                                             marker: SIMD3<Float>) {
        guard let currentPivot = manualNavigationPivot else {
            return
        }
        guard currentPivot.routeID == route.id else {
            manualNavigationPivot = nil
            return
        }

        let markerDelta = marker - currentPivot.marker
        if simd_length_squared(markerDelta) > Self.manualNavigationPivotEpsilon *
            Self.manualNavigationPivotEpsilon {
            cameraState.commit(CameraState.Transaction(cameraTarget: cameraState.cameraTarget + markerDelta))
        }
        manualNavigationPivot = ManualNavigationPivot(routeID: route.id,
                                                      marker: marker)
    }

    private static let manualNavigationPivotEpsilon: Float = 0.000_001
}

private struct NavigationArrivalRecovery {
    let routeID: UUID
    let recovery: NavigationCameraMode.ArrivalRecovery
}

private struct ManualNavigationPivot {
    let routeID: UUID
    let marker: SIMD3<Float>
}
