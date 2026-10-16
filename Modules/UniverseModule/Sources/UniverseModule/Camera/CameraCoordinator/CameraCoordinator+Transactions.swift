import CoreGraphics
import Foundation
import simd

extension CameraCoordinator {
    func updateManualCameraInertia(delta: Float) {
        commitManualCameraTransaction(
            zoomMode.update(delta: delta,
                            currentDistance: cameraState.cameraDistance)
        )
        commitManualCameraTransaction(
            orbitMode.update(delta: delta,
                             cameraOrientation: cameraState.cameraOrientation)
        )

    }

    func hasActiveCameraMotion(modeState: CameraFrameModeState) -> Bool {
        zoomMode.hasActiveInertia ||
        orbitMode.hasActiveInertia ||
        followCameraOwner.hasActiveTransition ||
        modeState.hasActiveExternalCameraMotion
    }

    func commitManualCameraTransaction(_ transaction: CameraState.Transaction?) {
        guard let transaction else { return }
        cameraState.commit(manualNavigationPivotTransaction(for: transaction) ?? transaction)
    }

    func commitNavigationCameraTransaction(snapshot: UniverseSceneSnapshot?,
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

    func navigationArrivalRecovery(routeID: UUID,
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

    func maximumCameraDistance(modeState: CameraFrameModeState,
                               viewportSize: CGSize) -> Float? {
        modeState.transfer?.maximumCameraDistance ??
        navigationCameraMode.maximumCameraDistance(state: modeState.navigation,
                                                   currentDistance: cameraState.cameraDistance,
                                                   viewportSize: viewportSize)
        ?? followCameraOwner.overviewMaximumDistance
    }

    func minimumCameraDistance(snapshot: UniverseSceneSnapshot?,
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
        guard transaction.cameraTarget == nil, transaction.preciseCameraTarget == nil else {
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
        var markerToCamera = SIMD3<Float>(currentPose.precisePosition - manualNavigationPivot.marker)

        if transaction.cameraOrientation != nil {
            let orientationDelta = simd_normalize(newOrientation * currentPose.orientation.inverse)
            markerToCamera = orientationDelta.act(markerToCamera)
        }
        if transaction.cameraDistance != nil {
            markerToCamera *= newDistance / currentPose.distance
        }

        let newCameraPosition = manualNavigationPivot.marker + SIMD3<Double>(markerToCamera)
        let newCameraTarget = newCameraPosition - SIMD3<Double>(newOrientation.act(SIMD3<Float>(0, 0, newDistance)))
        return CameraState.Transaction(cameraTarget: SIMD3<Float>(newCameraTarget),
                                       cameraDistance: transaction.cameraDistance,
                                       cameraOrientation: transaction.cameraOrientation,
                                           preciseCameraTarget: newCameraTarget)
    }

    func updateManualNavigationPivot(navigation: NavigationRouteRenderState) {
        guard let route = navigation.route,
              let marker = navigation.preciseMarkerPosition else {
            manualNavigationPivot = nil
            return
        }

        updateManualNavigationPivot(route: route,
                                    marker: marker)
    }

    func updateManualNavigationPivot(route: NavigationRoute,
                                     marker: SIMD3<Double>) {
        guard let currentPivot = manualNavigationPivot else {
            return
        }
        guard currentPivot.routeID == route.id else {
            manualNavigationPivot = nil
            return
        }

        let markerDelta = marker - currentPivot.marker
        // At 1× a body moves less than the old 1 km float threshold per frame.
        // Preserve every representable translation in the double-precision pivot.
        if simd_length_squared(markerDelta) > 0 {
            cameraState.commit(CameraState.Transaction(
                preciseCameraTarget: cameraState.preciseCameraTarget + markerDelta
            ))
        }
        manualNavigationPivot = ManualNavigationPivot(routeID: route.id,
                                                      marker: marker)
    }

    private static let manualNavigationPivotEpsilon: Float = 0.000_001
}

struct NavigationArrivalRecovery {
    let routeID: UUID
    let recovery: NavigationCameraMode.ArrivalRecovery
}

struct ManualNavigationPivot {
    let routeID: UUID
    let marker: SIMD3<Double>
}
