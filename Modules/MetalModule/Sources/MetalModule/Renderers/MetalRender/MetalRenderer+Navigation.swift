//
//  MetalRenderer+Navigation.swift
//  MetalModule
//
//  Created by max on 12.05.2026.
//
import simd

extension MetalRenderer {

    func startNavigation(to name: String) {
        guard let snapshot = renderPreparationPipeline.latestSnapshot,
              applyNavigation(named: name, snapshot: snapshot) else {
            pendingNavigationDestinationName = name
            cameraTransition = nil
            return
        }

        pendingNavigationDestinationName = nil
    }

    func pauseNavigation() {
        navigationRouteCoordinator.pause()
    }

    func resumeNavigation() {
        navigationRouteCoordinator.resume()
    }

    func cancelNavigation() {
        let destinationName = navigationRouteCoordinator.activeRouteForRendering?.destinationName
            ?? navigationRenderHandler.navigationSnapshot.destinationName
            ?? activeTransferDestinationName

        navigationRouteCoordinator.cancel()
        resetNavigationArrivalTransition()
        clearTransferOrbit()
        pendingNavigationDestinationName = nil
        navigationCameraFollowEnabled = true
        navigationRenderHandler.navigationCameraFollowEnabled = true

        guard let destinationName else { return }

        followingPlanetName = destinationName
        guard let snapshot = renderPreparationPipeline.latestSnapshot,
              startFollowAnimation(named: destinationName, snapshot: snapshot) else {
            pendingFollowPlanetName = destinationName
            cameraTransition = nil
            return
        }

        pendingFollowPlanetName = nil
    }

    func doneNavigation() {
        guard navigationRouteCoordinator.state == .completed else {
            cancelNavigation()
            return
        }

        let destinationName = navigationRouteCoordinator.activeRouteForRendering?.destinationName
            ?? navigationRenderHandler.navigationSnapshot.destinationName
            ?? activeTransferDestinationName

        navigationRouteCoordinator.cancel()
        resetNavigationArrivalTransition()
        clearTransferOrbit()
        pendingNavigationDestinationName = nil
        navigationCameraFollowEnabled = true
        navigationRenderHandler.navigationCameraFollowEnabled = true

        guard let destinationName else { return }

        followingPlanetName = destinationName
        pendingFollowPlanetName = nil

        guard let destinationPosition = renderPreparationPipeline
            .latestSnapshot?
            .worldPosition(ofPlanetNamed: destinationName) else {
            return
        }

        navigationCameraMode.set(destinationPosition: destinationPosition)
        updateCamera()
    }

    func setNavigationCameraFollowEnabled(_ isEnabled: Bool) {
        navigationCameraFollowEnabled = isEnabled
        navigationRenderHandler.navigationCameraFollowEnabled = isEnabled
        if isEnabled {
            cameraTransition = nil
        } else if let route = navigationRouteCoordinator.activeRouteForRendering,
                  let snapshot = renderPreparationPipeline.latestSnapshot {
            startNavigationOverviewAnimation(route: route, snapshot: snapshot)
        }
    }

    func applyNavigation(named name: String,
                         snapshot: PreparedRenderSnapshot) -> Bool {
        resetNavigationArrivalTransition()
        followingPlanetName = nil
        pendingFollowPlanetName = nil
        pendingSelectedPlanetName = nil

        guard let transferOrbit = makeTransferOrbit(destinationName: name,
                                                    snapshot: snapshot) else {
            clearTransferOrbit()
            followingPlanetName = name
            return startFollowAnimation(named: name, snapshot: snapshot)
        }

        activeTransferDestinationName = name
        activeTransferOrbit = transferOrbit

        guard navigationRouteCoordinator.start(destinationName: name,
                                               planets: planets,
                                               snapshot: snapshot),
              let route = navigationRouteCoordinator.route else {
            followingPlanetName = name
            return startFollowAnimation(named: name, snapshot: snapshot)
        }

        if navigationCameraFollowEnabled {
            cameraTransition = nil
            captureNavigationCameraTrailingOffset(route: route, snapshot: snapshot)
            updateNavigationFollowCamera(snapshot: snapshot)
        } else {
            startNavigationOverviewAnimation(route: route,
                                             snapshot: snapshot)
        }
        return true
    }

    private func startNavigationOverviewAnimation(route: NavigationRoute,
                                                  snapshot: PreparedRenderSnapshot) {
        guard let framing = earthCenteredNavigationFraming(route: route,
                                                           snapshot: snapshot) else {
            return
        }

        cameraTransition = CameraTransition(
            start: cameraState.currentCameraTransitionFrame,
            destination: .fixed(target: framing.center,
                                distance: distanceToFitPlanet(radius: framing.radius) * 1.08),
            duration: cameraState.cameraFollowTransitionDuration
        )
    }

    private func earthCenteredNavigationFraming(route: NavigationRoute,
                                                snapshot: PreparedRenderSnapshot)
    -> (center: SIMD3<Float>, radius: Float)? {
        guard let earthPosition = snapshot.worldPosition(ofPlanetNamed: route.originName) else {
            return nil
        }

        var framingRadius: Float = 0
        func include(center: SIMD3<Float>, radius: Float) {
            framingRadius = max(framingRadius,
                                simd_distance(earthPosition, center) + max(radius, 0))
        }

        for point in route.points {
            include(center: point, radius: 0)
        }

        if let sunPosition = snapshot.worldPosition(ofPlanetNamed: "Sun") {
            let routeOrbitRadius = route.points
                .map { simd_distance($0, sunPosition) }
                .max() ?? 0
            include(center: sunPosition, radius: routeOrbitRadius)
        }

        for planetName in ["Sun", route.originName, route.destinationName] {
            guard let planetPosition = snapshot.worldPosition(ofPlanetNamed: planetName) else {
                continue
            }
            include(center: planetPosition,
                    radius: snapshot.framingRadius(ofPlanetNamed: planetName) ?? 0)
        }

        guard framingRadius.isFinite else { return nil }
        return (earthPosition, max(framingRadius, 0.001))
    }

    private func captureNavigationCameraTrailingOffset(route: NavigationRoute,
                                                       snapshot: PreparedRenderSnapshot) {
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

    func updateNavigationFollowCamera(snapshot: PreparedRenderSnapshot) {
        guard let route = navigationRouteCoordinator.activeRouteForRendering,
              let currentPoint = navigationRouteCoordinator.currentRoutePoint,
              let destinationPosition = snapshot.worldPosition(ofPlanetNamed: route.destinationName) else {
            return
        }

        captureNavigationCameraTrailingOffset(route: route, snapshot: snapshot)

        viewMatrix = navigationCameraMode
            .makeNavigationFollowViewMatrix(route: route,
                                            currentPoint: currentPoint,
                                            destinationPosition: destinationPosition,
                                            trailingOffset: navigationCameraTrailingOffset)
        updateProjectionMatrix()
    }

    func updateNavigationArrivalCamera(snapshot: PreparedRenderSnapshot,
                                       delta: Float) {
        guard let route = navigationRouteCoordinator.activeRouteForRendering,
              let destinationPosition = snapshot.worldPosition(ofPlanetNamed: route.destinationName) else {
            return
        }

        let destinationRadius = snapshot.framingRadius(ofPlanetNamed: route.destinationName) ?? 0.01
        let arrivalDistance = distanceToFitPlanet(radius: destinationRadius)
        * navigationArrivalDistanceMultiplier
        if navigationArrivalRouteID != route.id {
            let existingDirection = simd_length_squared(cameraState.cameraPosition - destinationPosition) > 0.000001
            ? normalize(cameraState.cameraPosition - destinationPosition)
            : SIMD3<Float>(0, 0, 1)

            navigationArrivalRouteID = route.id
            navigationArrivalStartCameraPosition = cameraState.cameraPosition
            navigationArrivalStartTarget = cameraState.cameraTarget
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

        applyLookAtCamera(position: position,
                          target: target)
    }

    func resetNavigationArrivalTransition() {
        navigationArrivalRouteID = nil
        navigationArrivalProgress = 1
    }

    private func smoothStep(_ value: Float) -> Float {
        let clampedValue = min(max(value, 0), 1)
        return clampedValue * clampedValue * (3 - 2 * clampedValue)
    }

    private func applyLookAtCamera(position: SIMD3<Float>,
                                   target: SIMD3<Float>) {

        viewMatrix = navigationCameraMode
            .makeNavigationArrivalViewMatrix(position: position,
                                             target: target)
        updateProjectionMatrix()
    }
}
