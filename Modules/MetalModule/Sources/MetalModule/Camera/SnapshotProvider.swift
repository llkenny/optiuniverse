//
//  SnapshotProvider.swift
//  MetalModule
//
//  Created by max on 22.05.2026.
//

import CoreGraphics
import simd

struct NavigationCameraProjectionState {
    let destinationName: String
    let usesFollowNearPlane: Bool
    let routeProjectionRadius: Float?
}

/// Reads committed camera state, scene snapshots, viewport data, and time-dependent mode requirements.
/// It produces immutable camera snapshots containing render-ready matrices and derived camera values.
@MainActor
final class SnapshotProvider {

    // Input
    private let cameraState: CameraState
    private let snapshotSource: PreparedRenderSnapshotProviding

    var latestSnapshot: PreparedRenderSnapshot? {
        snapshotSource.latestSnapshot
    }

    struct CameraSnapshot {
        let renderViewMatrix: float4x4
        let projectionMatrix: float4x4
        let sceneOrigin: SIMD3<Float>
        let cameraPosition: SIMD3<Float>
        let viewportSize: CGSize
        let cameraRevision: Int
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
                            legacyNearPlane: Float,
                            legacyFarPlane: Float,
                            navigationProjectionState: NavigationCameraProjectionState?) -> CameraSnapshot {
        let nearPlane = navigationNearPlaneDistance(state: navigationProjectionState) ?? legacyNearPlane
        let farPlane = navigationFarPlaneDistance(state: navigationProjectionState) ?? legacyFarPlane
        let aspect = Float(viewportSize.width / max(viewportSize.height, 1))
        let projectionMatrix = float4x4.perspective(
            fov: CameraFit.verticalFieldOfView,
            aspect: aspect,
            near: nearPlane,
            far: max(farPlane, nearPlane + CameraFit.minimumNearPlane)
        )

        return CameraSnapshot(renderViewMatrix: cameraState.makeRenderViewMatrix(),
                              projectionMatrix: projectionMatrix,
                              sceneOrigin: cameraState.cameraTarget,
                              cameraPosition: cameraState.cameraOffset,
                              viewportSize: viewportSize,
                              cameraRevision: cameraState.revision)
    }

    private func navigationNearPlaneDistance(state: NavigationCameraProjectionState?) -> Float? {
        guard let state,
              state.usesFollowNearPlane,
              let framingRadius = latestSnapshot?.framingRadius(ofPlanetNamed: state.destinationName) else {
            return nil
        }

        let frontClearance = max(cameraState.cameraDistance - framingRadius, CameraFit.minimumNearPlane * 2)
        return min(CameraFit.defaultNearPlane,
                   max(CameraFit.minimumNearPlane, frontClearance * 0.5))
    }

    private func navigationFarPlaneDistance(state: NavigationCameraProjectionState?) -> Float? {
        guard let routeProjectionRadius = state?.routeProjectionRadius else {
            return nil
        }

        return max(CameraFit.defaultFarPlane,
                   cameraState.cameraDistance + routeProjectionRadius * 1.15)
    }
}
