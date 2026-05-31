//
//  SnapshotProvider.swift
//  MetalModule
//
//  Created by max on 22.05.2026.
//

import CoreGraphics
import simd

struct CameraProjectionParameters: Equatable {
    let nearPlane: Float
    let farPlane: Float
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
        let sceneFrameID: UInt64?
        let viewportSize: CGSize
        let projection: CameraProjectionParameters
    }

    struct CameraSnapshot {
        let renderViewMatrix: float4x4
        let projectionMatrix: float4x4
        let sceneOrigin: SIMD3<Float>
        let cameraPosition: SIMD3<Float>
        let viewportSize: CGSize
        let cameraRevision: Int
        let cameraDirtyFields: CameraState.DirtyFields
        let sceneFrameID: UInt64?
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

    func makeCameraSnapshot(viewportSize: CGSize,
                            projection: CameraProjectionParameters) -> CameraSnapshot {
        let sceneFrameID = latestSnapshot?.frameID
        let dependencyKey = CameraSnapshotDependencyKey(
            cameraRevision: cameraState.revision,
            cameraDirtyFields: cameraState.lastDirtyFields,
            sceneFrameID: sceneFrameID,
            viewportSize: viewportSize,
            projection: projection
        )
        if dependencyKey == cachedDependencyKey,
           let cachedCameraSnapshot {
            return cachedCameraSnapshot
        }

        let cameraPose = cameraState.pose
        let aspect = Float(viewportSize.width / max(viewportSize.height, 1))
        let projectionMatrix = float4x4.perspective(
            fov: CameraFit.verticalFieldOfView,
            aspect: aspect,
            near: projection.nearPlane,
            far: max(projection.farPlane, projection.nearPlane + CameraFit.minimumNearPlane)
        )

        let cameraSnapshot = CameraSnapshot(renderViewMatrix: cameraPose.makeRenderViewMatrix(),
                                            projectionMatrix: projectionMatrix,
                                            sceneOrigin: cameraPose.target,
                                            cameraPosition: cameraPose.offset,
                                            viewportSize: viewportSize,
                                            cameraRevision: cameraState.revision,
                                            cameraDirtyFields: cameraState.lastDirtyFields,
                                            sceneFrameID: sceneFrameID)
        cachedDependencyKey = dependencyKey
        cachedCameraSnapshot = cameraSnapshot
        return cameraSnapshot
    }
}
