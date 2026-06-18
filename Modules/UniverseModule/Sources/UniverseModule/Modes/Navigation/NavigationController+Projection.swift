//
//  NavigationController+Projection.swift
//  UniverseModule
//
//  Created by max on 25.05.2026.
//

import simd

extension NavigationController {
    func projectionParameters(snapshot: PreparedRenderSnapshot?,
                              baseProjection: CameraProjectionParameters) -> CameraProjectionParameters {
        guard let route = navigationRouteCoordinator.activeRouteForRendering else {
            return baseProjection
        }

        var nearPlane = baseProjection.nearPlane
        if navigationRouteCoordinator.isNavigationActive,
           navigationCameraFollowEnabled,
           let framingRadius = snapshot?.framingRadius(ofPlanetNamed: route.destinationName) {
            nearPlane = CameraFit.nearPlaneDistance(cameraDistance: cameraCoordinator.cameraDistance,
                                                    framingRadius: framingRadius)
        }

        var farPlane = baseProjection.farPlane
        if let snapshot,
           let routeProjectionRadius = routeProjectionRadius(snapshot: snapshot) {
            farPlane = max(farPlane,
                           CameraFit.defaultFarPlane,
                           cameraCoordinator.cameraDistance + routeProjectionRadius * 1.15)
        }

        return baseProjection.withClippingPlanes(nearPlane: nearPlane,
                                                 farPlane: farPlane)
    }

    func routeProjectionRadius(snapshot: PreparedRenderSnapshot) -> Float? {
        guard let route = navigationRouteCoordinator.activeRouteForRendering else {
            return nil
        }

        var radius: Float = 0

        func include(center: SIMD3<Float>, radius includedRadius: Float) {
            radius = max(radius,
                         simd_distance(cameraCoordinator.cameraTarget, center) + max(includedRadius, 0))
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

        guard radius.isFinite else { return nil }
        return max(radius, 0.001)
    }

    func earthCenteredNavigationFraming(route: NavigationRoute,
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

    func distanceToFitPlanet(radius: Float) -> Float {
        CameraFit.distanceToFit(radius: radius,
                                currentDistance: cameraCoordinator.cameraDistance,
                                viewportSize: viewportSize())
    }
}
