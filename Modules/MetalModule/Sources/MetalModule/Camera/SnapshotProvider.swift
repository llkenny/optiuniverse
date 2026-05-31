//
//  SnapshotProvider.swift
//  MetalModule
//
//  Created by max on 22.05.2026.
//

import CoreGraphics
import Foundation
import simd

struct CameraProjectionParameters: Equatable {
    let nearPlane: Float
    let farPlane: Float
}

struct CameraFollowSnapshotDependency: Equatable {
    let planetName: String
    let worldPosition: SIMD3<Float>?
    let framingRadius: Float?
    let hasActiveTransition: Bool
}

struct CameraNavigationSnapshotDependency: Equatable {
    let routeID: UUID?
    let destinationName: String?
    let progress: Float
    let state: NavigationRouteState
    let hasActiveTransition: Bool
    let arrivalProgress: Float
}

struct CameraTransferSnapshotDependency: Equatable {
    let destinationName: String?
    let hasActiveTransition: Bool
}

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

struct CameraSnapshotDependencies: Equatable {
    let followedObject: CameraFollowSnapshotDependency?
    let navigation: CameraNavigationSnapshotDependency?
    let transfer: CameraTransferSnapshotDependency?
    let activeCameraMotionRevision: Int
    let sceneFrameID: UInt64?
    let viewportSize: CGSize
    let projection: CameraProjectionParameters
}

/// Reads committed camera state, scene snapshots, viewport data, and explicit projection requirements.
/// It produces immutable camera snapshots containing render-ready matrices and derived camera values.
@MainActor
final class SnapshotProvider {

    // Input
    private let cameraState: CameraState
    private let snapshotSource: PreparedRenderSnapshotProviding
    private var cachedCameraSnapshot: CameraSnapshot?
    private var cachedDependencyKey: CameraSnapshotDependencyKey?

    var latestSnapshot: PreparedRenderSnapshot? {
        snapshotSource.latestSnapshot
    }

    private struct CameraSnapshotDependencyKey: Equatable {
        let cameraRevision: Int
        let cameraDirtyFields: CameraState.DirtyFields
        let dependencies: CameraSnapshotDependencies
    }

    struct CameraSnapshot {
        let renderViewMatrix: float4x4
        let projectionMatrix: float4x4
        let sceneOrigin: SIMD3<Float>
        let cameraOffset: SIMD3<Float>
        let cameraWorldPosition: SIMD3<Float>
        let viewportSize: CGSize
        let cameraRevision: Int
        let cameraDirtyFields: CameraState.DirtyFields
        let sceneFrameID: UInt64?
        let dependencies: CameraSnapshotDependencies
    }

    init(cameraState: CameraState,
         snapshotSource: PreparedRenderSnapshotProviding) {
        self.snapshotSource = snapshotSource
        self.cameraState = cameraState
    }

    convenience init(snapshotSource: PreparedRenderSnapshotProviding) {
        self.init(cameraState: CameraState(),
                  snapshotSource: snapshotSource)
    }

    func requestPreparation(simulationTime: Float) {
        snapshotSource.requestPreparation(simulationTime: simulationTime)
    }

    func makeCameraSnapshot(dependencies: CameraSnapshotDependencies) -> CameraSnapshot {
        let dependencyKey = CameraSnapshotDependencyKey(
            cameraRevision: cameraState.revision,
            cameraDirtyFields: cameraState.lastDirtyFields,
            dependencies: dependencies
        )
        if dependencyKey == cachedDependencyKey,
           let cachedCameraSnapshot {
            return cachedCameraSnapshot
        }

        let cameraPose = cameraState.pose
        let aspect = Float(dependencies.viewportSize.width / max(dependencies.viewportSize.height, 1))
        let projectionMatrix = float4x4.perspective(
            fov: CameraFit.verticalFieldOfView,
            aspect: aspect,
            near: dependencies.projection.nearPlane,
            far: max(dependencies.projection.farPlane,
                     dependencies.projection.nearPlane + CameraFit.minimumNearPlane)
        )

        let cameraSnapshot = CameraSnapshot(renderViewMatrix: cameraPose.makeRenderViewMatrix(),
                                            projectionMatrix: projectionMatrix,
                                            sceneOrigin: cameraPose.target,
                                            cameraOffset: cameraPose.offset,
                                            cameraWorldPosition: cameraPose.position,
                                            viewportSize: dependencies.viewportSize,
                                            cameraRevision: cameraState.revision,
                                            cameraDirtyFields: cameraState.lastDirtyFields,
                                            sceneFrameID: dependencies.sceneFrameID,
                                            dependencies: dependencies)
        cachedDependencyKey = dependencyKey
        cachedCameraSnapshot = cameraSnapshot
        return cameraSnapshot
    }
}
