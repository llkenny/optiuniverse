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
        let preciseOrigin: SIMD3<Double>
        let preciseOverviewCenter: SIMD3<Double>
    }

    private let departurePhaseEnd: Float = 0.1
    private let arrivalPhaseStart: Float = 0.9
    private let arrivalTargetPhaseDuration: Float = 0.35
    private let arrivalDistancePhaseDuration: Float = 0.8
    private let missionCameraMode = MissionCameraMode()
    private let starshipCameraMode = StarshipCameraMode()
    private let crew13CameraMode = Crew13CameraMode()
    private let voyagerCameraMode = VoyagerCameraMode()

    func makeNavigationTransaction(state: NavigationRouteRenderState,
                                   snapshot: UniverseSceneSnapshot?,
                                   viewportSize: CGSize,
                                   currentPose: CameraPose,
                                   arrivalRecovery: ArrivalRecovery? = nil) -> CameraState.Transaction? {
        if state.route?.hasMissionVehicles == true {
            return makeVehicleTransaction(state: state, viewportSize: viewportSize, currentPose: currentPose)
        }
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
            return makeCameraTransaction(frame: makeCruiseFrame(route: route, progress: progress,
                                                               snapshot: snapshot,
                                                               overviewDistance: departureContext.overviewDistance))
        }

        let arrivalFrame = makeArrivalFrame(
            progress: progress,
            overview: CameraTransition.Frame(target: route.overviewCenter,
                                             distance: departureContext.overviewDistance,
                                             preciseTarget: route.preciseOverviewCenter),
            destination: makeDestinationFrame(route: route, snapshot: snapshot,
                                              fallback: destination, distance: destinationDistance)
        )
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
        guard let route = state.route, !route.hasMissionVehicles else { return false }
        return simd_clamp(state.progress, 0, 1) >= arrivalPhaseStart
    }

    /// A spacecraft pivot can move through the planet even when its zoom distance is valid.
    /// Back the camera out along its viewing axis, retaining the user's target and orientation.
    func makeManualCameraClearanceTransaction(state: NavigationRouteRenderState,
                                              currentPose: CameraPose) -> CameraState.Transaction? {
        let voyager = state.elapsedTime < 64 ? state.voyagerFlight : nil
        guard !state.isCameraAutoFramingEnabled,
              let earthRadius = voyager?.focusRadius ?? state.route?.missionEarthRadius,
              let earthCenter = voyager?.focusCenter ?? state.route?.missionEarthPreciseCenter else { return nil }
        let radius = CameraFit.minimumDistanceOutsideBody(radius: earthRadius)
        let relativePosition = SIMD3<Float>(currentPose.precisePosition - earthCenter)
        let distanceSquared = simd_length_squared(relativePosition)
        guard distanceSquared < radius * radius else { return nil }

        let backward = currentPose.orientation.act(SIMD3<Float>(0, 0, 1))
        let projection = simd_dot(relativePosition, backward)
        let exitDistance = -projection + sqrt(projection * projection + radius * radius - distanceSquared)
        return CameraState.Transaction(cameraDistance: currentPose.distance + exitDistance)
    }

    private func makeDestinationFrame(route: NavigationRoute, snapshot: UniverseSceneSnapshot?,
                                      fallback: SIMD3<Float>, distance: Float) -> CameraTransition.Frame {
        CameraTransition.Frame(target: fallback, distance: distance,
                               preciseTarget: snapshot?.planet(named: route.destinationName)?.preciseWorldPosition
                                   ?? route.precisePoints.last ?? SIMD3<Double>(fallback))
    }

    private func makeVehicleTransaction(state: NavigationRouteRenderState,
                                        viewportSize: CGSize, currentPose: CameraPose) -> CameraState.Transaction? {
        if state.route?.voyagerProfile != nil {
            guard state.isCameraAutoFramingEnabled,
                  let frame = voyagerCameraMode.frame(state: state, viewportSize: viewportSize,
                                                       currentPose: currentPose) else { return nil }
            return makeCameraTransaction(frame: frame)
        }
        if state.route?.crew13Profile != nil {
            guard state.isCameraAutoFramingEnabled,
                  let frame = crew13CameraMode.frame(state: state, viewportSize: viewportSize,
                                                     currentPose: currentPose) else { return nil }
            return makeCameraTransaction(frame: frame)
        }
        if state.route?.starshipProfile != nil {
            guard state.isCameraAutoFramingEnabled,
                  let frame = starshipCameraMode.frame(state: state, viewportSize: viewportSize,
                                                       currentPose: currentPose) else { return nil }
            return makeCameraTransaction(frame: frame)
        }
        return nil
    }

    private func makeCameraTransaction(frame: CameraTransition.Frame) -> CameraState.Transaction {
        CameraState.Transaction(cameraTarget: frame.target,
                                cameraDistance: frame.distance,
                                cameraOrientation: frame.orientation, preciseCameraTarget: frame.preciseTarget)
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
            preciseOrigin: snapshot?.planet(named: route.originName)?.preciseWorldPosition
                ?? route.precisePoints.first ?? SIMD3<Double>(originFallback),
            preciseOverviewCenter: route.preciseOverviewCenter
        )
    }

    private func makeDepartureFrame(route: NavigationRoute,
                                    progress: Float,
                                    context: DepartureFrameContext) -> CameraTransition.Frame {
        if let missionFrame = missionCameraMode.makeDepartureFrame(
            route: route,
            progress: progress,
            originFrame: CameraTransition.Frame(target: context.origin, distance: context.originDistance),
            overviewFrame: CameraTransition.Frame(target: context.overviewCenter, distance: context.overviewDistance)
        ) {
            let phase = ArtemisRouteProfile.easedOpeningProgress(routeProgress: progress,
                                                                  estimatedDuration: route.estimatedDuration)
            let marker = route.precisePoint(at: progress) ?? context.preciseOrigin
            let target: SIMD3<Double>
            if phase <= 0.45 {
                let fraction = Double(CameraTransition.easeInOutCubic(phase / 0.45))
                target = context.preciseOrigin + (marker - context.preciseOrigin) * fraction
            } else {
                let fraction = Double(CameraTransition.easeInOutCubic((phase - 0.45) / 0.55))
                target = marker + (context.preciseOverviewCenter - marker) * fraction
            }
            return CameraTransition.preservingPrecision(missionFrame, target: target)
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
            ), preciseTarget: context.preciseOrigin +
                (context.preciseOverviewCenter - context.preciseOrigin) * Double(phaseProgress)
        )
    }

    private func makeOverviewFrame(center: SIMD3<Float>,
                                   distance: Float,
                                   preciseCenter: SIMD3<Double>) -> CameraTransition.Frame {
        CameraTransition.Frame(target: center,
                               distance: distance,
                               orientation: OverviewCameraFraming.orientation, preciseTarget: preciseCenter)
    }

    private func makeArrivalFrame(progress: Float,
                                  overview: CameraTransition.Frame,
                                  destination: CameraTransition.Frame) -> CameraTransition.Frame {
        let phaseProgress = (progress - arrivalPhaseStart) / (1 - arrivalPhaseStart)
        let targetProgress = CameraTransition.easeInOutCubic(
            phaseProgress / arrivalTargetPhaseDuration
        )
        let distanceProgress = CameraTransition.easeInOutCubic(
            phaseProgress / arrivalDistancePhaseDuration
        )
        return CameraTransition.Frame(
            target: interpolate(from: overview.target,
                                to: destination.target,
                                progress: targetProgress),
            distance: interpolate(from: overview.distance,
                                  to: destination.distance,
                                  progress: distanceProgress),
            orientation: OverviewCameraFraming.orientation,
            preciseTarget: overview.preciseTarget + (destination.preciseTarget
                - overview.preciseTarget) * Double(targetProgress)
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

}

private extension NavigationCameraMode {
    func makeCruiseFrame(route: NavigationRoute, progress: Float,
                         snapshot: UniverseSceneSnapshot?, overviewDistance: Float) -> CameraTransition.Frame {
        missionCameraMode.makeCruiseFrame(route: route, progress: progress,
                                         snapshot: snapshot, overviewDistance: overviewDistance)
            ?? makeOverviewFrame(center: route.overviewCenter, distance: overviewDistance,
                                 preciseCenter: route.preciseOverviewCenter)
    }
}

extension NavigationCameraMode {
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
        if let flight = state.voyagerFlight {
            return max(CameraFit.minimumNearPlane * 2, flight.vehicleScale * 2)
        }
        if let radius = state.route?.missionEarthRadius {
            return max(CameraFit.minimumNearPlane * 2, radius * 0.12)
        }
        if let missionMinimumDistance = missionCameraMode.minimumCameraDistance(
            state: state,
            snapshot: snapshot,
            baseMinimumDistance: baseMinimumDistance
        ) {
            return missionMinimumDistance
        }

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
            nearPlane: route.hasMissionVehicles ? CameraFit.minimumNearPlane : nil,
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
        missionCameraMode.departurePhaseEnd(route: route) ?? departurePhaseEnd
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
