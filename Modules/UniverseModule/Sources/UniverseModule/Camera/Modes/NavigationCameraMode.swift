//
//  NavigationCameraMode.swift
//  UniverseModule
//
//  Created by Codex on 02.07.2026.
//

import CoreGraphics
import simd

final class NavigationCameraMode {
    private let departurePhaseEnd: Float = 0.1
    private let arrivalPhaseStart: Float = 0.9

    func makeNavigationTransaction(state: NavigationRouteRenderState,
                                   snapshot: UniverseSceneSnapshot?,
                                   viewportSize: CGSize,
                                   currentPose: CameraPose) -> CameraState.Transaction? {
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

        let frame: CameraTransition.Frame
        if progress <= departurePhaseEnd {
            let phaseProgress = progress / departurePhaseEnd
            frame = CameraTransition.Frame(
                target: interpolate(from: origin,
                                    to: route.overviewCenter,
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
        } else if progress < arrivalPhaseStart {
            frame = CameraTransition.Frame(
                target: route.overviewCenter,
                distance: overviewDistance,
                orientation: OverviewCameraFraming.orientation
            )
        } else {
            let phaseProgress = (progress - arrivalPhaseStart) / (1 - arrivalPhaseStart)
            frame = CameraTransition.Frame(
                target: interpolate(from: route.overviewCenter,
                                    to: destination,
                                    progress: phaseProgress),
                distance: interpolate(from: overviewDistance,
                                      to: destinationDistance,
                                      progress: phaseProgress),
                orientation: OverviewCameraFraming.orientation
            )
        }

        return CameraState.Transaction(cameraTarget: frame.target,
                                       cameraDistance: frame.distance,
                                       cameraOrientation: frame.orientation)
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
