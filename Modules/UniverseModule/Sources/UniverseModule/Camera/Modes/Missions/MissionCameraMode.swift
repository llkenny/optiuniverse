//
//  MissionCameraMode.swift
//  UniverseModule
//
//  Created by Codex on 07.09.2026.
//

import simd

final class MissionCameraMode {
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
        let closeUpFrame = makeLunarFlybyMarkerFrame(marker: marker,
                                                     waypoint: waypoint,
                                                     waypointRadius: waypointRadius)

        return CameraTransition.interpolate(
            from: CameraTransition.Frame(target: route.overviewCenter,
                                         distance: overviewDistance,
                                         orientation: OverviewCameraFraming.orientation),
            to: closeUpFrame,
            progress: closeUpProgress
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

    private func makeLunarFlybyMarkerFrame(marker: SIMD3<Float>,
                                           waypoint: SIMD3<Float>,
                                           waypointRadius: Float) -> CameraTransition.Frame {
        let markerOffset = marker - waypoint
        let markerDistance = simd_length(markerOffset)
        let minimumDistance = CameraFit.minimumDistanceOutsideBody(radius: waypointRadius,
                                                                  baseMinimumDistance: CameraFit.minimumNearPlane)
        let distance = max(markerDistance, minimumDistance)
        let offsetDirection = markerDistance > lunarFlybyOrientationEpsilon
            ? markerOffset / markerDistance
            : OverviewCameraFraming.orientation.act(SIMD3<Float>(0, 0, 1))

        return CameraTransition.Frame(
            target: waypoint,
            distance: distance,
            orientation: makeLunarFlybyCameraOrientation(
                offsetDirection: offsetDirection,
                upSeed: OverviewCameraFraming.orientation.act(SIMD3<Float>(0, 1, 0))
            )
        )
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

private func makeLunarFlybyCameraOrientation(offsetDirection: SIMD3<Float>,
                                             upSeed: SIMD3<Float>) -> simd_quatf {
    let epsilonSquared = lunarFlybyOrientationEpsilon * lunarFlybyOrientationEpsilon
    let normalizedOffset = simd_length_squared(offsetDirection) > epsilonSquared
        ? simd_normalize(offsetDirection)
        : SIMD3<Float>(0, 0, 1)
    let normalizedUpSeed = simd_length_squared(upSeed) > epsilonSquared
        ? simd_normalize(upSeed)
        : SIMD3<Float>(0, 1, 0)
    let candidateUp = abs(simd_dot(normalizedOffset, normalizedUpSeed)) > 0.94
        ? lunarFlybyFallbackUpVector(offsetDirection: normalizedOffset)
        : normalizedUpSeed
    let right = simd_normalize(simd_cross(candidateUp, normalizedOffset))
    let cameraUpDirection = simd_normalize(simd_cross(normalizedOffset, right))

    return simd_normalize(simd_quatf(
        float3x3(columns: (right, cameraUpDirection, normalizedOffset))
    ))
}

private func lunarFlybyFallbackUpVector(offsetDirection: SIMD3<Float>) -> SIMD3<Float> {
    let candidates = [
        SIMD3<Float>(1, 0, 0),
        SIMD3<Float>(0, 1, 0),
        SIMD3<Float>(0, 0, 1)
    ]

    return candidates.min {
        abs(simd_dot(offsetDirection, $0)) < abs(simd_dot(offsetDirection, $1))
    } ?? SIMD3<Float>(0, 1, 0)
}
