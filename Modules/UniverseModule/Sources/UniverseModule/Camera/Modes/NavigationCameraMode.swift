//
//  NavigationCameraMode.swift
//  UniverseModule
//
//  Created by Codex on 02.07.2026.
//

import CoreGraphics
import simd

final class NavigationCameraMode {
    struct ArrivalRecovery: Equatable {
        let startFrame: CameraTransition.Frame
        let startProgress: Float
    }

    private let departurePhaseEnd: Float = 0.1
    private let arrivalPhaseStart: Float = 0.9
    private let arrivalTargetPhaseDuration: Float = 0.35
    private let arrivalDistancePhaseDuration: Float = 0.8

    func makeNavigationTransaction(state: NavigationRouteRenderState,
                                   snapshot: UniverseSceneSnapshot?,
                                   viewportSize: CGSize,
                                   currentPose: CameraPose,
                                   arrivalRecovery: ArrivalRecovery? = nil) -> CameraState.Transaction? {
        guard let route = state.route,
              let originFallback = route.points.first,
              let destinationFallback = route.points.last else {
            return nil
        }

        let progress = simd_clamp(state.progress, 0, 1)
        let origin = snapshot?.worldPosition(ofPlanetNamed: route.originName) ?? originFallback
        let destination = snapshot?.worldPosition(ofPlanetNamed: route.destinationName) ?? destinationFallback
        let originDistance = fitDistance(for: route.originName,
                                         fallbackDistance: currentPose.distance,
                                         snapshot: snapshot,
                                         viewportSize: viewportSize)
        let destinationDistance = fitDistance(for: route.destinationName,
                                              fallbackDistance: currentPose.distance,
                                              snapshot: snapshot,
                                              viewportSize: viewportSize)
        let overviewDistance = OverviewCameraFraming.navigationOverviewDistance(
            route: route,
            currentDistance: currentPose.distance,
            viewportSize: viewportSize
        )

        if progress <= departurePhaseEnd {
            return makeCameraTransaction(
                frame: makeDepartureFrame(progress: progress,
                                          origin: origin,
                                          originDistance: originDistance,
                                          overviewDistance: overviewDistance,
                                          overviewCenter: route.overviewCenter,
                                          currentPose: currentPose)
            )
        }

        if progress < arrivalPhaseStart {
            return makeCameraTransaction(
                frame: makeOverviewFrame(center: route.overviewCenter,
                                         distance: overviewDistance)
            )
        }

        let arrivalFrame = makeArrivalFrame(progress: progress,
                                            overviewCenter: route.overviewCenter,
                                            overviewDistance: overviewDistance,
                                            destination: destination,
                                            destinationDistance: destinationDistance)
        if let arrivalRecovery {
            return makeCameraTransaction(
                frame: makeArrivalRecoveryFrame(progress: progress,
                                                arrivalFrame: arrivalFrame,
                                                recovery: arrivalRecovery)
            )
        }

        return makeCameraTransaction(frame: arrivalFrame)
    }

    func isArrivalPhase(state: NavigationRouteRenderState) -> Bool {
        guard state.route != nil else { return false }
        return simd_clamp(state.progress, 0, 1) >= arrivalPhaseStart
    }

    private func makeCameraTransaction(frame: CameraTransition.Frame) -> CameraState.Transaction {
        CameraState.Transaction(cameraTarget: frame.target,
                                cameraDistance: frame.distance,
                                cameraOrientation: frame.orientation)
    }

    private func makeDepartureFrame(progress: Float,
                                    origin: SIMD3<Float>,
                                    originDistance: Float,
                                    overviewDistance: Float,
                                    overviewCenter: SIMD3<Float>,
                                    currentPose: CameraPose) -> CameraTransition.Frame {
        let phaseProgress = progress / departurePhaseEnd
        return CameraTransition.Frame(
            target: interpolate(from: origin,
                                to: overviewCenter,
                                progress: phaseProgress),
            distance: interpolate(from: originDistance,
                                  to: overviewDistance,
                                  progress: phaseProgress),
            orientation: simd_normalize(
                simd_slerp(currentPose.orientation,
                           OverviewCameraFraming.orientation,
                           phaseProgress)
            )
        )
    }

    private func makeOverviewFrame(center: SIMD3<Float>,
                                   distance: Float) -> CameraTransition.Frame {
        CameraTransition.Frame(target: center,
                               distance: distance,
                               orientation: OverviewCameraFraming.orientation)
    }

    private func makeArrivalFrame(progress: Float,
                                  overviewCenter: SIMD3<Float>,
                                  overviewDistance: Float,
                                  destination: SIMD3<Float>,
                                  destinationDistance: Float) -> CameraTransition.Frame {
        let phaseProgress = (progress - arrivalPhaseStart) / (1 - arrivalPhaseStart)
        let targetProgress = CameraTransition.easeInOutCubic(
            phaseProgress / arrivalTargetPhaseDuration
        )
        let distanceProgress = CameraTransition.easeInOutCubic(
            phaseProgress / arrivalDistancePhaseDuration
        )
        return CameraTransition.Frame(
            target: interpolate(from: overviewCenter,
                                to: destination,
                                progress: targetProgress),
            distance: interpolate(from: overviewDistance,
                                  to: destinationDistance,
                                  progress: distanceProgress),
            orientation: OverviewCameraFraming.orientation
        )
    }

    private func makeArrivalRecoveryFrame(progress: Float,
                                          arrivalFrame: CameraTransition.Frame,
                                          recovery: ArrivalRecovery) -> CameraTransition.Frame {
        let clampedStartProgress = simd_clamp(recovery.startProgress, arrivalPhaseStart, 1)
        let clampedProgress = simd_clamp(progress, clampedStartProgress, 1)
        let remainingProgress = max(1 - clampedStartProgress, .leastNonzeroMagnitude)
        let recoveryProgress = (clampedProgress - clampedStartProgress) / remainingProgress

        return CameraTransition.interpolate(from: recovery.startFrame,
                                            to: arrivalFrame,
                                            progress: CameraTransition.easeInOutCubic(recoveryProgress))
    }

    func maximumCameraDistance(state: NavigationRouteRenderState,
                               currentDistance: Float,
                               viewportSize: CGSize) -> Float? {
        guard let route = state.route else { return nil }

        return OverviewCameraFraming.navigationMaximumCameraDistance(
            route: route,
            currentDistance: currentDistance,
            viewportSize: viewportSize
        )
    }

    func minimumCameraDistance(state: NavigationRouteRenderState,
                               snapshot: UniverseSceneSnapshot?,
                               baseMinimumDistance: Float) -> Float? {
        guard let route = state.route,
              simd_clamp(state.progress, 0, 1) >= arrivalPhaseStart,
              let framingRadius = snapshot?.framingRadius(ofPlanetNamed: route.destinationName) else {
            return nil
        }

        return max(baseMinimumDistance, framingRadius * 1.05)
    }

    func projectionParameters(state: NavigationRouteRenderState,
                              cameraDistance: Float,
                              baseProjection: CameraProjectionParameters) -> CameraProjectionParameters {
        guard let route = state.route else {
            return baseProjection
        }

        return baseProjection.withClippingPlanes(
            farPlane: max(baseProjection.farPlane,
                          CameraFit.defaultFarPlane,
                          cameraDistance + OverviewCameraFraming.navigationRouteRadius(route: route) * 2)
        )
    }

    private func fitDistance(for planetName: String,
                             fallbackDistance: Float,
                             snapshot: UniverseSceneSnapshot?,
                             viewportSize: CGSize) -> Float {
        CameraFit.distanceToFit(radius: snapshot?.framingRadius(ofPlanetNamed: planetName) ?? 0,
                                currentDistance: fallbackDistance,
                                viewportSize: viewportSize)
    }

    private func interpolate(from start: SIMD3<Float>,
                             to end: SIMD3<Float>,
                             progress: Float) -> SIMD3<Float> {
        start + (end - start) * simd_clamp(progress, 0, 1)
    }

    private func interpolate(from start: Float,
                             to end: Float,
                             progress: Float) -> Float {
        start + (end - start) * simd_clamp(progress, 0, 1)
    }
}
