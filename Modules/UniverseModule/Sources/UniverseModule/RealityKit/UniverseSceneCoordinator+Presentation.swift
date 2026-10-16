import CoreGraphics
import RealityKit
import SwiftUI
import simd

extension UniverseSceneCoordinator {
    struct BodyEntities {
        let bodyRoot: Entity
        let orbitTransform: Entity
        let rotationTransform: Entity
        let visualRoot: Entity
    }

    var hasImmersiveFocus: Bool {
        immersiveFocusState.hasFocus && !hasImmersiveTransferOverview
    }

    private var hasImmersiveTransferOverview: Bool {
        transferOrbitController.isTransferPreviewActive ||
        immersiveTransferOverviewState.hasPersistedTransform
    }

    func beginImmersiveTransferOverview() {
        immersiveTransferOverviewState.begin()
        applyImmersiveFocusIfPossible(frameState: latestFrameState)
    }

    func clearImmersiveTransferOverview() {
        immersiveTransferOverviewState.clear()
        immersiveTransferOverviewTransform = nil
        applyImmersiveFocusIfPossible(frameState: latestFrameState)
    }

    func setImmersiveFocus(bodyName: String) {
        immersiveFocusState.focus(on: bodyName)
        applyImmersiveFocusIfPossible(frameState: latestFrameState)
    }

    func clearImmersiveFocus() {
        immersiveFocusState.clear()
        immersiveTransferOverviewState.clear()
        immersiveFocusTransform = nil
        immersiveTransferOverviewTransform = nil
        applyImmersiveFocusIfPossible(frameState: latestFrameState)
    }

    func adjustImmersiveFocusRotation(translation: CGSize) -> Bool {
        guard !hasImmersiveTransferOverview else { return false }
        guard immersiveFocusState.rotate(translation: translation) else { return false }
        applyImmersiveFocusIfPossible(frameState: latestFrameState)
        return true
    }

    func adjustImmersiveFocusScale(by scale: Float) -> Bool {
        guard !hasImmersiveTransferOverview else { return false }
        guard immersiveFocusState.scale(by: scale) else { return false }
        applyImmersiveFocusIfPossible(frameState: latestFrameState)
        return true
    }

    func makeCameraFrameModeState() -> CameraFrameModeState {
        CameraFrameModeState(
            transferPreviewActive: transferOrbitController.isTransferPreviewActive,
            transfer: transferOrbitController.cameraSnapshotDependency,
            navigation: navigationController.routeRenderState
        )
    }

    func makeCameraProjection(
        snapshot: UniverseSceneSnapshot?,
        overlayAdjustment: ObjectInfoOverlayFramingState.ProjectionAdjustment,
        modeState: CameraFrameModeState
    ) -> CameraProjectionParameters {
        let baseProjection = CameraProjectionParameters(
            nearPlane: CameraFit.defaultNearPlane,
            farPlane: CameraFit.defaultFarPlane,
            verticalFieldOfView: overlayAdjustment.verticalFieldOfView,
            verticalCenterOffset: overlayAdjustment.verticalCenterOffset
        )
        let followProjection = cameraCoordinator.followProjectionParameters(snapshot: snapshot,
                                                                            baseProjection: baseProjection)
        let navigationProjection = cameraCoordinator.navigationProjectionParameters(
            modeState: modeState,
            baseProjection: followProjection
        )
        return transferOrbitController.projectionParameters(snapshot: snapshot,
                                                            baseProjection: navigationProjection)
    }

    func makeCameraSnapshot(
        snapshot: UniverseSceneSnapshot?,
        projection: CameraProjectionParameters,
        modeState: CameraFrameModeState
    ) -> SnapshotProvider.CameraSnapshot {
        let dependencies = cameraCoordinator.makeSnapshotDependencies(
            snapshot: snapshot,
            viewportSize: viewportSize,
            projection: projection,
            modeState: modeState
        )
        return snapshotProvider.makeCameraSnapshot(dependencies: dependencies)
    }

    func apply(frameState: UniverseFrameState) {
        let cameraSnapshot = frameState.cameraSnapshot
        let cameraTransform = simd_inverse(cameraSnapshot.renderViewMatrix)
            * Self.realityKitCameraBasis
        let projectionMatrix = Self.makeRealityKitProjection(from: cameraSnapshot)
        virtualCamera.setTransformMatrix(cameraTransform,
                                         relativeTo: universeRoot)
        virtualCamera.components.set(
            ProjectiveTransformCameraComponent(projectionMatrix: projectionMatrix)
        )

        proceduralSceneContent?.update(frameState: frameState)

        guard let snapshot = frameState.snapshot else { return }
        for packet in snapshot.planets {
            guard let entities = bodyEntities[packet.planetName] else { continue }
            entities.bodyRoot.position = EphemerisCoordinates.renderPosition(packet.preciseWorldPosition,
                                                         relativeTo: cameraSnapshot.resolvedSceneOrigin)
            entities.orbitTransform.transform = .identity
            entities.rotationTransform.transform = Transform(matrix: packet.visualRotationMatrix)
            if bodyDescriptors[packet.planetName]?.usesSnapshotScale == true {
                entities.visualRoot.scale = SIMD3<Float>(repeating: packet.normalizedScale)
            }
        }
        applyImmersiveFocusIfPossible(frameState: frameState)
    }

    func applyImmersiveFocusIfPossible(frameState: UniverseFrameState?) {
        if transferOrbitController.isTransferPreviewActive,
           let frameState,
           let transform = immersiveTransferOverviewState.persist(
                cameraPose: cameraCoordinator.currentCameraPose,
                targetAfterSceneOrigin: cameraCoordinator.currentCameraPose.target
                    - frameState.cameraSnapshot.sceneOrigin
           ) {
            immersiveTransferOverviewTransform = transform
            installationRoot?.transform = Transform(matrix: transform)
            return
        }

        if let transform = immersiveTransferOverviewState.persistedTransform {
            immersiveTransferOverviewTransform = transform
            installationRoot?.transform = Transform(matrix: transform)
            return
        }

        immersiveTransferOverviewTransform = nil
        guard immersiveFocusState.hasFocus else {
            immersiveFocusTransform = nil
            installationRoot?.transform = .identity
            return
        }
        guard let frameState,
              let snapshot = frameState.snapshot,
              let bodyName = immersiveFocusState.bodyName,
              let bodySnapshot = snapshot.planet(named: bodyName),
              let transform = immersiveFocusState.transform(
                  selectedBodyPositionAfterSceneOrigin: EphemerisCoordinates.renderPosition(
                    bodySnapshot.preciseWorldPosition, relativeTo: frameState.cameraSnapshot.resolvedSceneOrigin),
                  framingRadius: bodySnapshot.framingRadius
              ) else {
            return
        }

        immersiveFocusTransform = transform
        installationRoot?.transform = Transform(matrix: transform)
    }

    static func makeRealityKitProjection(
        from cameraSnapshot: SnapshotProvider.CameraSnapshot
    ) -> float4x4 {
        let legacyProjection = cameraSnapshot.projectionMatrix
        let near = cameraSnapshot.dependencies.projection.nearPlane
        let far = cameraSnapshot.dependencies.projection.farPlane
        let reverseDepthScale = near / (far - near)
        let reverseDepthTranslation = far * reverseDepthScale

        // ProjectiveTransformCameraComponent requires reverse depth. The camera basis
        // converts the legacy +Z camera into RealityKit's -Z camera, and the projection
        // keeps the app's intended screen-space left/right and up/down mapping.
        return float4x4(
            [legacyProjection[0][0], 0, 0, 0],
            [0, legacyProjection[1][1], 0, 0],
            [0, -legacyProjection[2][1], reverseDepthScale, -1],
            [0, 0, reverseDepthTranslation, 0]
        )
    }

    func logSurfaceCoordinateDebug(snapshot: UniverseSceneSnapshot?,
                                   cameraSnapshot: SnapshotProvider.CameraSnapshot,
                                   modeState: CameraFrameModeState) {
        guard let snapshot,
              let bodyName = surfaceCoordinateDebugTargetName(cameraSnapshot: cameraSnapshot,
                                                              modeState: modeState),
              let planet = snapshot.planet(named: bodyName) else {
            return
        }

        surfaceCoordinateDebugLogger.logIfNeeded(bodyName: bodyName,
                                                 planet: planet,
                                                 snapshot: snapshot,
                                                 cameraSnapshot: cameraSnapshot)
    }

    private func surfaceCoordinateDebugTargetName(
        cameraSnapshot: SnapshotProvider.CameraSnapshot,
        modeState: CameraFrameModeState
    ) -> String? {
        return cameraSnapshot.dependencies.followedObject?.planetName
    }

    func handleEphemerisFailure() {
        if navigationController.isNavigationActive || navigationController.pendingNavigationRequest != nil {
            let pending = navigationController.pendingNavigationRequest
            navigationController.navigationRouteCoordinator.failForEphemeris(mission: pending?.mission,
                                                                            destinationName: pending?.destinationName)
            navigationController.pendingNavigationRequest = nil
            navigationController.requestedMissionReplay = nil
            synchronizeLiveScene()
        }
    }
}
