//
//  MissionRouteHandler.swift
//  UniverseModule
//
//  Created by Codex on 07.09.2026.
//

import Foundation

protocol NavigationRouteMissionHandling {
    func refreshedRoute(for route: NavigationRoute,
                        state: NavigationRouteState,
                        progress: Float,
                        planets: [Planet],
                        snapshot: UniverseSceneSnapshot,
                        routeBuilder: RouteBuilding) -> NavigationRoute?
    func routeProgress(linearProgress: Float,
                       route: NavigationRoute) -> Float?
}

struct MissionRouteHandler: NavigationRouteMissionHandling {
    func refreshedRoute(for route: NavigationRoute,
                        state: NavigationRouteState,
                        progress: Float,
                        planets: [Planet],
                        snapshot: UniverseSceneSnapshot,
                        routeBuilder: RouteBuilding) -> NavigationRoute? {
        if route.hasMissionVehicles {
            return refreshedEarthMission(route: route, snapshot: snapshot)
        }
        guard ArtemisRouteProfile.isArtemisRoute(route),
              state == .running || state == .completed,
              let sunPosition = snapshot.worldPosition(ofPlanetNamed: "Sun"),
              let earthPosition = snapshot.worldPosition(ofPlanetNamed: "Earth"),
              let originPosition = snapshot.worldPosition(ofPlanetNamed: route.originName),
              let destinationPosition = snapshot.worldPosition(ofPlanetNamed: route.destinationName),
              let refreshedRoute = routeBuilder.makeRoute(input: RouteBuildInput(
                originName: route.originName,
                waypointName: route.waypointName,
                destinationName: route.destinationName,
                planets: planets,
                originPosition: originPosition,
                waypointPosition: route.waypointName.flatMap {
                    snapshot.worldPosition(ofPlanetNamed: $0)
                },
                originSurfaceRadius: snapshot.surfaceRadius(ofPlanetNamed: route.originName) ?? 0,
                waypointSurfaceRadius: route.waypointName.flatMap {
                    snapshot.surfaceRadius(ofPlanetNamed: $0)
                } ?? 0,
                destinationSurfaceRadius: snapshot.surfaceRadius(ofPlanetNamed: route.destinationName) ?? 0,
                earthSunDirection: earthPosition - sunPosition,
                sunPosition: sunPosition,
                destinationPosition: destinationPosition,
                estimatedDuration: route.estimatedDuration,
                simulationTime: snapshot.simulationTime,
                routeProgress: progress
              )) else {
            return nil
        }

        return route.replacingPath(
            points: refreshedRoute.points,
            cumulativeDistances: refreshedRoute.cumulativeDistances,
            totalDistance: refreshedRoute.totalDistance,
            overviewPaddingRadius: refreshedRoute.overviewPaddingRadius,
            overviewCenter: refreshedRoute.overviewCenter
        )
    }

    private func refreshedEarthMission(route: NavigationRoute,
                                       snapshot: UniverseSceneSnapshot) -> NavigationRoute? {
        guard let center = route.missionEarthCenter, let earth = snapshot.planet(named: "Earth"),
              earth.worldPosition.x.isFinite, earth.worldPosition.y.isFinite,
              earth.worldPosition.z.isFinite else { return nil }
        let offset = earth.worldPosition - center
        return NavigationRoute(id: route.id, originName: route.originName, waypointName: route.waypointName,
                               destinationName: route.destinationName, points: route.points.map { $0 + offset },
                               cumulativeDistances: route.cumulativeDistances, totalDistance: route.totalDistance,
                               estimatedDuration: route.estimatedDuration,
                               overviewPaddingRadius: route.overviewPaddingRadius, overviewCenter: earth.worldPosition,
                               mission: route.mission,
                               starshipProfile: route.starshipProfile?.translated(to: earth.worldPosition),
                               crew13Profile: route.crew13Profile?.translated(to: earth.worldPosition))
    }

    func routeProgress(linearProgress: Float,
                       route: NavigationRoute) -> Float? {
        guard ArtemisRouteProfile.isArtemisRoute(route) else {
            return nil
        }

        return ArtemisRouteProfile.routeProgress(
            linearProgress: linearProgress,
            estimatedDuration: route.estimatedDuration
        )
    }
}
