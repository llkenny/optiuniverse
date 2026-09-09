//
//  MissionCameraMode.swift
//  UniverseModule
//
//  Created by Codex on 07.09.2026.
//

import Foundation
import simd

final class MissionCameraMode {
    private struct FlybyHeadingReference {
        var routeID: UUID?
        var approach: Float = 0
        var departure: Float = 0
    }

    private var flybyHeadingReference = FlybyHeadingReference()

    func departurePhaseEnd(route: NavigationRoute) -> Float? {
        guard ArtemisRouteProfile.isArtemisRoute(route) else {
            return nil
        }

        return ArtemisRouteProfile.openingPhaseEnd(estimatedDuration: route.estimatedDuration)
    }

    func makeDepartureFrame(route: NavigationRoute,
                            progress: Float,
                            origin: SIMD3<Float>,
                            originDistance: Float,
                            overviewDistance: Float,
                            overviewCenter: SIMD3<Float>) -> CameraTransition.Frame? {
        guard ArtemisRouteProfile.isArtemisRoute(route) else {
            return nil
        }

        let phaseProgress = ArtemisRouteProfile.easedOpeningProgress(
            routeProgress: progress,
            estimatedDuration: route.estimatedDuration
        )
        return CameraTransition.Frame(
            target: makeArtemisOpeningTarget(route: route,
                                             progress: progress,
                                             origin: origin,
                                             overviewCenter: overviewCenter,
                                             phaseProgress: phaseProgress),
            distance: interpolate(from: originDistance,
                                  to: overviewDistance,
                                  progress: phaseProgress),
            orientation: OverviewCameraFraming.orientation
        )
    }

    func makeCruiseFrame(route: NavigationRoute,
                         progress: Float,
                         snapshot: UniverseSceneSnapshot?,
                         overviewDistance: Float) -> CameraTransition.Frame? {
        guard ArtemisRouteProfile.isArtemisRoute(route),
              let waypointName = route.waypointName else {
            return nil
        }

        let closeUpProgress = ArtemisRouteProfile.lunarFlybyCloseUpProgress(routeProgress: progress)
        guard closeUpProgress > 0 else {
            return nil
        }

        let waypoint = snapshot?.worldPosition(ofPlanetNamed: waypointName)
            ?? route.point(at: ArtemisRouteProfile.lunarEncounterProgress)
        guard let waypoint else {
            return nil
        }

        let waypointRadius = snapshot?.framingRadius(ofPlanetNamed: waypointName) ?? 0
        let marker = route.point(at: progress)
            ?? route.point(at: ArtemisRouteProfile.lunarEncounterProgress)
            ?? waypoint
        let markerOffset = marker - waypoint
        let minimumDistance = CameraFit.minimumDistanceOutsideBody(
            radius: waypointRadius,
            baseMinimumDistance: CameraFit.minimumNearPlane
        )
        let markerDistance = simd_length(markerOffset)
        let pitch = markerDistance > lunarFlybyOrientationEpsilon
            ? -asin(simd_clamp(markerOffset.y / markerDistance, -1, 1))
            : -.pi * 0.25

        // Unwrap the heading along the route instead of choosing a new shortest quaternion
        // arc every frame. Each blend retains its overview boundary's unwrapped heading
        // across refreshed geometry, so crossing the angle seam cannot reverse the blend.
        let boundary = progress < ArtemisRouteProfile.lunarFlybyCloseUpFullStartProgress
            ? ArtemisRouteProfile.lunarFlybyCloseUpStartProgress
            : ArtemisRouteProfile.lunarFlybyCloseUpEndProgress
        let yaw = lunarFlybyHeading(route: route,
                                   waypoint: waypoint,
                                   boundary: boundary,
                                   progress: progress)
        let orientation = simd_quatf(angle: yaw * closeUpProgress, axis: SIMD3<Float>(0, 1, 0))
            * simd_quatf(angle: interpolate(from: -.pi * 0.25,
                                            to: pitch,
                                            progress: closeUpProgress),
                         axis: SIMD3<Float>(1, 0, 0))

        return CameraTransition.Frame(
            target: interpolate(from: route.overviewCenter, to: waypoint, progress: closeUpProgress),
            distance: interpolate(from: overviewDistance,
                                  to: max(markerDistance, minimumDistance),
                                  progress: closeUpProgress),
            orientation: simd_normalize(orientation)
        )
    }

    func minimumCameraDistance(state: NavigationRouteRenderState,
                               snapshot: UniverseSceneSnapshot?,
                               baseMinimumDistance: Float) -> Float? {
        guard state.isCameraAutoFramingEnabled,
              let route = state.route,
              ArtemisRouteProfile.isArtemisRoute(route),
              let waypointName = route.waypointName,
              ArtemisRouteProfile.isLunarFlybyCloseUpActive(routeProgress: simd_clamp(state.progress, 0, 1)),
              let framingRadius = snapshot?.framingRadius(ofPlanetNamed: waypointName) else {
            return nil
        }

        return CameraFit.minimumDistanceOutsideBody(radius: framingRadius,
                                                    baseMinimumDistance: baseMinimumDistance)
    }

    private func makeArtemisOpeningTarget(route: NavigationRoute,
                                          progress: Float,
                                          origin: SIMD3<Float>,
                                          overviewCenter: SIMD3<Float>,
                                          phaseProgress: Float) -> SIMD3<Float> {
        let markerPoint = route.point(at: progress) ?? origin
        let markerFocusEnd: Float = 0.45
        guard phaseProgress > markerFocusEnd else {
            return interpolate(from: origin,
                               to: markerPoint,
                               progress: CameraTransition.easeInOutCubic(phaseProgress / markerFocusEnd))
        }

        let overviewProgress = CameraTransition.easeInOutCubic(
            (phaseProgress - markerFocusEnd) / (1 - markerFocusEnd)
        )
        return interpolate(from: markerPoint,
                           to: overviewCenter,
                           progress: overviewProgress)
    }

    private func lunarFlybyHeading(route: NavigationRoute,
                                   waypoint: SIMD3<Float>,
                                   boundary: Float,
                                   progress: Float) -> Float {
        if flybyHeadingReference.routeID != route.id {
            flybyHeadingReference = FlybyHeadingReference(routeID: route.id)
        }
        let isApproach = boundary == ArtemisRouteProfile.lunarFlybyCloseUpStartProgress
        var heading = isApproach ? flybyHeadingReference.approach : flybyHeadingReference.departure
        func follow(_ point: SIMD3<Float>) {
            let offset = point - waypoint
            // Retain the heading if the marker is directly above or below the Moon.
            guard offset.x * offset.x + offset.z * offset.z
                    > lunarFlybyOrientationEpsilon * lunarFlybyOrientationEpsilon else { return }
            let angle = atan2(offset.x, offset.z)
            let delta = angle - heading
            heading += atan2(sin(delta), cos(delta))
        }

        if let point = route.point(at: boundary) { follow(point) }
        // Store the boundary heading, not the marker heading: route traversal below
        // must not accumulate an extra revolution when the same frame is evaluated again.
        if isApproach {
            flybyHeadingReference.approach = heading
        } else {
            flybyHeadingReference.departure = heading
        }
        let boundaryDistance = route.distance(at: boundary)
        let currentDistance = route.distance(at: progress)
        let forward = boundary <= progress
        let indices = stride(from: forward ? 0 : route.points.count - 1,
                             to: forward ? route.points.count : -1,
                             by: forward ? 1 : -1)
        for index in indices where index < route.cumulativeDistances.count {
            let distance = route.cumulativeDistances[index]
            if distance > min(boundaryDistance, currentDistance),
               distance < max(boundaryDistance, currentDistance) {
                follow(route.points[index])
            }
        }
        if let point = route.point(at: progress) { follow(point) }
        return heading
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

private let lunarFlybyOrientationEpsilon: Float = 0.000_001
