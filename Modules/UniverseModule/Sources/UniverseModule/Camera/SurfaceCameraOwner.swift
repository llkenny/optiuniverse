//
//  SurfaceCameraOwner.swift
//  UniverseModule
//
//  Created by Codex on 06.06.2026.
//

import simd

/// Drives the surface-location portion of the follow camera pipeline.
///
/// The owner waits for the parent body follow transition to finish, then rotates the camera around
/// that body's center until the requested surface coordinate is front-facing. After the rotation
/// completes, it applies a one-time distance-only zoom toward the body while keeping the surface
/// coordinate aligned.
@MainActor
final class SurfaceCameraOwner {
    private enum Phase: Equatable {
        case idle
        case waitingForBody
        case surfaceTransition
        case zoomTransition
        case steady
    }

    private struct ActiveTransition {
        let startOrientation: simd_quatf
        let duration: Float
        var elapsed: Float = 0

        var progress: Float {
            guard duration > 0 else { return 1 }
            return min(max(elapsed / duration, 0), 1)
        }

        var isComplete: Bool {
            progress >= 1
        }
    }

    private struct ActiveZoom {
        let startDistance: Float
        let targetDistance: Float
        let duration: Float
        var elapsed: Float = 0

        var progress: Float {
            guard duration > 0 else { return 1 }
            return min(max(elapsed / duration, 0), 1)
        }

        var isComplete: Bool {
            progress >= 1
        }
    }

    private unowned let cameraState: CameraState
    private let surfaceMode: SurfaceCameraMode
    private let surfaceZoomFactor: Float = 0.5

    private var bodyName: String?
    private var coordinate: SurfaceCoordinate?
    private var phase: Phase = .idle
    private var cameraTransition: ActiveTransition?
    private var zoomTransition: ActiveZoom?

    init(cameraState: CameraState,
         surfaceMode: SurfaceCameraMode = SurfaceCameraMode()) {
        self.cameraState = cameraState
        self.surfaceMode = surfaceMode
    }

    var controlsCamera: Bool {
        phase != .idle
    }

    var requiresBodyFollow: Bool {
        phase == .waitingForBody
    }

    var hasActiveMotion: Bool {
        phase == .waitingForBody || phase == .surfaceTransition || phase == .zoomTransition
    }

    func focus(on bodyName: String,
               coordinate: SurfaceCoordinate) {
        self.bodyName = bodyName
        self.coordinate = coordinate
        self.cameraTransition = nil
        self.zoomTransition = nil
        self.phase = .waitingForBody
    }

    func cancel() {
        bodyName = nil
        coordinate = nil
        phase = .idle
        cameraTransition = nil
        zoomTransition = nil
    }

    func update(snapshot: PreparedRenderSnapshot?,
                delta: Float,
                isSuppressed: Bool,
                bodyFollowTransitionActive: Bool) {
        guard !isSuppressed else { return }
        guard let snapshot,
              let bodyName,
              let coordinate else {
            return
        }

        switch phase {
        case .idle:
            return
        case .waitingForBody:
            guard !bodyFollowTransitionActive else { return }
            startSurfaceTransition(bodyName: bodyName,
                                   coordinate: coordinate,
                                   snapshot: snapshot)
        case .surfaceTransition:
            if cameraTransition == nil {
                startSurfaceTransition(bodyName: bodyName,
                                       coordinate: coordinate,
                                       snapshot: snapshot)
            }
            updateCameraTransition(snapshot: snapshot,
                                   delta: delta)
        case .zoomTransition:
            if zoomTransition == nil {
                startZoomTransition()
            }
            updateZoomTransition(bodyName: bodyName,
                                 coordinate: coordinate,
                                 snapshot: snapshot,
                                 delta: delta)
        case .steady:
            commitSteadySurfaceFrame(bodyName: bodyName,
                                     coordinate: coordinate,
                                     snapshot: snapshot)
        }
    }

    private func startSurfaceTransition(bodyName: String,
                                        coordinate: SurfaceCoordinate,
                                        snapshot: PreparedRenderSnapshot) {
        guard surfaceMode.makeSurfaceFrame(bodyName: bodyName,
                                           coordinate: coordinate,
                                           snapshot: snapshot,
                                           currentPose: cameraState.pose) != nil else {
            return
        }

        cameraTransition = ActiveTransition(startOrientation: cameraState.cameraOrientation,
                                            duration: cameraState.cameraFollowTransitionDuration)
        zoomTransition = nil
        phase = .surfaceTransition
    }

    private func updateCameraTransition(snapshot: PreparedRenderSnapshot,
                                        delta: Float) {
        guard var transition = cameraTransition else { return }
        guard let bodyName,
              let coordinate,
              let destinationFrame = surfaceMode.makeSurfaceFrame(bodyName: bodyName,
                                                                  coordinate: coordinate,
                                                                  snapshot: snapshot,
                                                                  currentPose: cameraState.pose) else {
            return
        }

        transition.elapsed = min(max(transition.elapsed + max(delta, 0), 0),
                                 transition.duration)
        let orientation = simd_slerp(
            transition.startOrientation,
            destinationFrame.orientation,
            CameraTransition.easeInOutCubic(transition.progress)
        )
        let frame = SurfaceCameraMode.Frame(target: destinationFrame.target,
                                            distance: destinationFrame.distance,
                                            orientation: orientation)

        if transition.isComplete {
            cameraTransition = nil
            phase = .zoomTransition
        } else {
            cameraTransition = transition
        }
        cameraState.commit(surfaceMode.makeSurfaceTransaction(frame: frame))
    }

    private func startZoomTransition() {
        zoomTransition = ActiveZoom(
            startDistance: cameraState.cameraDistance,
            targetDistance: cameraState.cameraDistance * surfaceZoomFactor,
            duration: cameraState.cameraFollowTransitionDuration
        )
    }

    private func updateZoomTransition(bodyName: String,
                                      coordinate: SurfaceCoordinate,
                                      snapshot: PreparedRenderSnapshot,
                                      delta: Float) {
        guard var transition = zoomTransition,
              let destinationFrame = surfaceMode.makeSurfaceFrame(bodyName: bodyName,
                                                                  coordinate: coordinate,
                                                                  snapshot: snapshot,
                                                                  currentPose: cameraState.pose) else {
            return
        }

        transition.elapsed = min(max(transition.elapsed + max(delta, 0), 0),
                                 transition.duration)
        let progress = CameraTransition.easeInOutCubic(transition.progress)
        let distance = transition.startDistance +
            (transition.targetDistance - transition.startDistance) * progress
        let frame = SurfaceCameraMode.Frame(target: destinationFrame.target,
                                            distance: distance,
                                            orientation: destinationFrame.orientation)

        zoomTransition = transition.isComplete ? nil : transition
        if transition.isComplete {
            phase = .steady
        }
        cameraState.commit(surfaceMode.makeSurfaceTransaction(frame: frame))
    }

    private func commitSteadySurfaceFrame(bodyName: String,
                                          coordinate: SurfaceCoordinate,
                                          snapshot: PreparedRenderSnapshot) {
        guard let frame = surfaceMode.makeSurfaceFrame(bodyName: bodyName,
                                                       coordinate: coordinate,
                                                       snapshot: snapshot,
                                                       currentPose: cameraState.pose) else {
            return
        }

        cameraState.commit(surfaceMode.makeSurfaceTransaction(frame: frame))
    }
}
