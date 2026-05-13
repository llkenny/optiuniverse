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

        guard let snapshot = renderPreparationPipeline.latestSnapshot,
              let destinationPosition = snapshot.worldPosition(ofPlanetNamed: destinationName) else {
            return
        }

        cameraTarget = destinationPosition
        cameraOffset = cameraPosition - destinationPosition
        cameraDistance = max(simd_length(cameraOffset), CameraFit.minimumNearPlane)
        alignCameraOrientationToCurrentLookAt()
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
        transferCameraTargetOffset = .zero

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
            start: currentCameraTransitionFrame,
            destination: .fixed(target: framing.center,
                                distance: distanceToFitPlanet(radius: framing.radius) * 1.08),
            duration: cameraFollowTransitionDuration
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

        let cameraEye = currentPoint + navigationCameraTrailingOffset
        let localTarget = destinationPosition - currentPoint
        let localEye = cameraEye - currentPoint

        cameraTarget = currentPoint
        cameraPosition = cameraEye
        cameraOffset = localEye
        cameraDistance = max(simd_length(cameraOffset), CameraFit.minimumNearPlane)

        let fallbackUp = SIMD3<Float>(0, 1, 0)
        let viewDirection = normalize(localTarget - localEye)
        let candidateUp = abs(simd_dot(viewDirection, fallbackUp)) > 0.94
        ? SIMD3<Float>(1, 0, 0)
        : fallbackUp
        let right = normalize(simd_cross(candidateUp, viewDirection))
        cameraUp = normalize(simd_cross(viewDirection, right))

        viewMatrix = float4x4.lookAt(
            eye: localEye,
            target: localTarget,
            upVector: cameraUp
        )
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
            let existingDirection = simd_length_squared(cameraPosition - destinationPosition) > 0.000001
            ? normalize(cameraPosition - destinationPosition)
            : SIMD3<Float>(0, 0, 1)

            navigationArrivalRouteID = route.id
            navigationArrivalStartCameraPosition = cameraPosition
            navigationArrivalStartTarget = cameraTarget
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
        let localEye = position - target
        let viewDirection = simd_length_squared(-localEye) > 0.000001
        ? normalize(-localEye)
        : SIMD3<Float>(0, 0, -1)
        let fallbackUp = SIMD3<Float>(0, 1, 0)
        let candidateUp = abs(simd_dot(viewDirection, fallbackUp)) > 0.94
        ? SIMD3<Float>(1, 0, 0)
        : fallbackUp
        let right = normalize(simd_cross(candidateUp, viewDirection))

        cameraTarget = target
        cameraOffset = localEye
        cameraPosition = position
        cameraDistance = max(simd_length(localEye), CameraFit.minimumNearPlane)
        cameraUp = normalize(simd_cross(viewDirection, right))

        viewMatrix = float4x4.lookAt(
            eye: localEye,
            target: .zero,
            upVector: cameraUp
        )
        updateProjectionMatrix()
    }
}
