//
//  NavigationController+Camera.swift
//  UniverseModule
//
//  Created by max on 25.05.2026.
//

import simd

extension NavigationController {
    func updateNavigationCamera(snapshot: UniverseSceneSnapshot,
                                delta: Float) {
        if navigationRouteCoordinator.state == .completed {
            navigationCameraFollowEnabled = true
            updateNavigationArrivalCamera(snapshot: snapshot,
                                          delta: delta)
            return
        }

        if navigationRouteCoordinator.isNavigationActive,
           navigationCameraFollowEnabled {
            resetNavigationArrivalTransition()
            updateNavigationFollowCamera(snapshot: snapshot)
            return
        }

        if cameraTransition != nil {
            resetNavigationArrivalTransition()
            updateCameraTransition(snapshot: snapshot,
                                   delta: delta)
        }
    }

    func startNavigationOverviewAnimation(route: NavigationRoute,
                                          snapshot: UniverseSceneSnapshot) {
        guard let framing = earthCenteredNavigationFraming(route: route,
                                                           snapshot: snapshot) else {
            return
        }

        cameraTransition = CameraTransition(
            start: cameraCoordinator.currentCameraTransitionFrame,
            destination: .fixed(target: framing.center,
                                distance: distanceToFitPlanet(radius: framing.radius) * 1.08),
            duration: cameraCoordinator.cameraFollowTransitionDuration
        )
        cameraCoordinator.claimNavigationCameraControl(routeID: route.id)
    }

    func captureNavigationCameraTrailingOffset(route: NavigationRoute,
                                               snapshot: UniverseSceneSnapshot) {
        guard let currentPoint = route.point(at: navigationRouteCoordinator.renderProgress),
              let destinationPosition = snapshot.worldPosition(ofPlanetNamed: route.destinationName) else {
            navigationCameraTrailingOffset = SIMD3<Float>(0, 0, 0.18)
            return
        }

        let routeDistance = max(simd_distance(currentPoint, destinationPosition), 0.001)
        let destinationRadius = snapshot.framingRadius(ofPlanetNamed: route.destinationName) ?? 0.01
        let desiredTrailingDistance = min(max(destinationRadius * 4, routeDistance * 0.08), 35)
        let trailingDistance = min(desiredTrailingDistance, max(routeDistance * 0.45, 0.002))
        let destinationDirection = simd_length_squared(destinationPosition - currentPoint) > 0.000001
        ? normalize(destinationPosition - currentPoint)
        : SIMD3<Float>(0, 0, -1)
        let lift = SIMD3<Float>(0, 0, max(trailingDistance * 0.25, destinationRadius * 2))

        navigationCameraTrailingOffset = destinationDirection * trailingDistance + lift
    }

    func updateNavigationFollowCamera(snapshot: UniverseSceneSnapshot) {
        guard let route = navigationRouteCoordinator.activeRouteForRendering,
              let currentPoint = navigationRouteCoordinator.currentRoutePoint,
              let destinationPosition = snapshot.worldPosition(ofPlanetNamed: route.destinationName) else {
            return
        }

        captureNavigationCameraTrailingOffset(route: route, snapshot: snapshot)
        cameraCoordinator.commitNavigationFollow(route: route,
                                                 currentPoint: currentPoint,
                                                 destinationPosition: destinationPosition,
                                                 trailingOffset: navigationCameraTrailingOffset)
    }

    func updateNavigationArrivalCamera(snapshot: UniverseSceneSnapshot,
                                       delta: Float) {
        guard let route = navigationRouteCoordinator.activeRouteForRendering,
              let destinationPosition = snapshot.worldPosition(ofPlanetNamed: route.destinationName) else {
            return
        }

        let destinationRadius = snapshot.framingRadius(ofPlanetNamed: route.destinationName) ?? 0.01
        let arrivalDistance = distanceToFitPlanet(radius: destinationRadius)
        * navigationArrivalDistanceMultiplier
        if navigationArrivalRouteID != route.id {
            let currentPose = cameraCoordinator.currentCameraPose
            let currentOffset = currentPose.position - destinationPosition
            let existingDirection = simd_length_squared(currentOffset) > 0.000001
            ? normalize(currentOffset)
            : SIMD3<Float>(0, 0, 1)

            navigationArrivalRouteID = route.id
            navigationArrivalStartCameraPosition = currentPose.position
            navigationArrivalStartTarget = cameraCoordinator.cameraTarget
            navigationArrivalTargetOffset = existingDirection * arrivalDistance
            navigationArrivalProgress = 0
        }

        navigationArrivalProgress = min(navigationArrivalProgress + delta / navigationArrivalDuration, 1)
        let easedProgress = smoothStep(navigationArrivalProgress)
        let target = navigationArrivalStartTarget
        + (destinationPosition - navigationArrivalStartTarget) * easedProgress
        let finalPosition = destinationPosition + navigationArrivalTargetOffset
        let position = navigationArrivalStartCameraPosition
        + (finalPosition - navigationArrivalStartCameraPosition) * easedProgress

        cameraCoordinator.commitNavigationArrival(route: route,
                                                  position: position,
                                                  target: target)
    }

    func resetNavigationArrivalTransition() {
        navigationArrivalRouteID = nil
        navigationArrivalProgress = 1
    }

    func updateCameraTransition(snapshot: UniverseSceneSnapshot?,
                                delta: Float) {
        guard var transition = cameraTransition else { return }
        guard let frame = transition.advance(delta: delta, resolveDestination: { [weak self] destination in
            guard let self else { return nil }
            return self.resolveCameraTransitionDestination(destination,
                                                           snapshot: snapshot)
        }) else {
            return
        }

        cameraTransition = transition.isComplete ? nil : transition
        guard let routeID = navigationRouteCoordinator.activeRouteForRendering?.id else { return }
        cameraCoordinator.commitNavigationTransition(routeID: routeID,
                                                     frame: frame)
    }

    func resolveCameraTransitionDestination(_ destination: CameraTransition.Destination,
                                            snapshot: UniverseSceneSnapshot?)
    -> CameraTransition.Frame? {
        switch destination {
        case .planet(let name):
            guard let snapshot else { return nil }
            return resolvedPlanetTransitionFrame(named: name,
                                                 snapshot: snapshot)
        case .fixed(let target, let distance):
            return CameraTransition.Frame(target: target,
                                          distance: distance)
        }
    }

    func resolvedPlanetTransitionFrame(named name: String,
                                       snapshot: UniverseSceneSnapshot)
    -> CameraTransition.Frame? {
        guard let position = snapshot.worldPosition(ofPlanetNamed: name),
              let framingRadius = snapshot.framingRadius(ofPlanetNamed: name) else {
            return nil
        }

        return CameraTransition.Frame(target: position,
                                      distance: distanceToFitPlanet(radius: framingRadius))
    }

    func smoothStep(_ value: Float) -> Float {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue * clampedValue * (3 - 2 * clampedValue)
    }
}
