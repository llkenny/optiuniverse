//
//  NavigationCameraMode.swift
//  UniverseModule
//
//  Created by Codex on 02.07.2026.
//

import CoreGraphics
import Foundation
import simd

final class NavigationCameraMode {
    struct ArrivalRecovery: Equatable {
        let startFrame: CameraTransition.Frame
        let startProgress: Float
    }

    private struct DepartureFrameContext {
        let phaseEnd: Float
        let origin: SIMD3<Float>
        let originDistance: Float
        let overviewDistance: Float
        let overviewCenter: SIMD3<Float>
        let currentPose: CameraPose
        let estimatedDuration: TimeInterval
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
        let destination = snapshot?.worldPosition(ofPlanetNamed: route.destinationName) ?? destinationFallback
        let destinationDistance = fitDistance(for: route.destinationName,
                                              fallbackDistance: currentPose.distance,
                                              snapshot: snapshot,
                                              viewportSize: viewportSize)
        let departureContext = makeDepartureContext(
            route: route,
            snapshot: snapshot,
            viewportSize: viewportSize,
            currentPose: currentPose,
            originFallback: originFallback
        )

        if progress <= departureContext.phaseEnd {
            return makeCameraTransaction(
                frame: makeDepartureFrame(route: route,
                                          progress: progress,
                                          context: departureContext)
            )
        }

        if progress < arrivalPhaseStart {
            return makeCameraTransaction(
                frame: makeOverviewFrame(center: route.overviewCenter,
                                         distance: departureContext.overviewDistance)
            )
        }

        let arrivalFrame = makeArrivalFrame(progress: progress,
                                            overviewCenter: route.overviewCenter,
                                            overviewDistance: departureContext.overviewDistance,
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

    private func makeDepartureContext(route: NavigationRoute,
                                      snapshot: UniverseSceneSnapshot?,
                                      viewportSize: CGSize,
                                      currentPose: CameraPose,
                                      originFallback: SIMD3<Float>) -> DepartureFrameContext {
        DepartureFrameContext(
            phaseEnd: departurePhaseEnd(for: route),
            origin: snapshot?.worldPosition(ofPlanetNamed: route.originName) ?? originFallback,
            originDistance: fitDistance(for: route.originName,
                                        fallbackDistance: currentPose.distance,
                                        snapshot: snapshot,
                                        viewportSize: viewportSize),
            overviewDistance: OverviewCameraFraming.navigationOverviewDistance(
                route: route,
                currentDistance: currentPose.distance,
                viewportSize: viewportSize
            ),
            overviewCenter: route.overviewCenter,
            currentPose: currentPose,
            estimatedDuration: route.estimatedDuration
        )
    }

    private func makeDepartureFrame(route: NavigationRoute,
                                    progress: Float,
                                    context: DepartureFrameContext) -> CameraTransition.Frame {
        if isArtemisRoute(route) {
            return makeArtemisOpeningFrame(route: route,
                                           progress: progress,
                                           context: context)
        }

        return makeStandardDepartureFrame(progress: progress,
                                          context: context)
    }

    private func makeStandardDepartureFrame(progress: Float,
                                            context: DepartureFrameContext) -> CameraTransition.Frame {
        let phaseProgress = progress / context.phaseEnd
        return CameraTransition.Frame(
            target: interpolate(from: context.origin,
                                to: context.overviewCenter,
                                progress: phaseProgress),
            distance: interpolate(from: context.originDistance,
                                  to: context.overviewDistance,
                                  progress: phaseProgress),
            orientation: simd_normalize(
                simd_slerp(context.currentPose.orientation,
                           OverviewCameraFraming.orientation,
                           phaseProgress)
            )
        )
    }

    private func makeArtemisOpeningFrame(route: NavigationRoute,
                                         progress: Float,
                                         context: DepartureFrameContext) -> CameraTransition.Frame {
        let phaseProgress = ArtemisRouteProfile.easedOpeningProgress(
            routeProgress: progress,
            estimatedDuration: context.estimatedDuration
        )
        return CameraTransition.Frame(
            target: makeArtemisOpeningTarget(route: route,
                                             progress: progress,
                                             phaseProgress: phaseProgress,
                                             context: context),
            distance: interpolate(from: context.originDistance,
                                  to: context.overviewDistance,
                                  progress: phaseProgress),
            orientation: OverviewCameraFraming.orientation
        )
    }

    private func makeArtemisOpeningTarget(route: NavigationRoute,
                                          progress: Float,
                                          phaseProgress: Float,
                                          context: DepartureFrameContext) -> SIMD3<Float> {
        let markerPoint = route.point(at: progress) ?? context.origin
        let markerFocusEnd: Float = 0.45
        guard phaseProgress > markerFocusEnd else {
            return interpolate(from: context.origin,
                               to: markerPoint,
                               progress: CameraTransition.easeInOutCubic(phaseProgress / markerFocusEnd))
        }

        let overviewProgress = CameraTransition.easeInOutCubic(
            (phaseProgress - markerFocusEnd) / (1 - markerFocusEnd)
        )
        return interpolate(from: markerPoint,
                           to: context.overviewCenter,
                           progress: overviewProgress)
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

        return CameraFit.minimumDistanceOutsideBody(radius: framingRadius,
                                                    baseMinimumDistance: baseMinimumDistance)
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

    private func departurePhaseEnd(for route: NavigationRoute) -> Float {
        ArtemisRouteProfile.isArtemisRoute(route)
            ? ArtemisRouteProfile.openingPhaseEnd(estimatedDuration: route.estimatedDuration)
            : departurePhaseEnd
    }

    private func isArtemisRoute(_ route: NavigationRoute) -> Bool {
        ArtemisRouteProfile.isArtemisRoute(route)
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
