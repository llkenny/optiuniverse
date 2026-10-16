//
//  MissionRouteHandler.swift
//  UniverseModule
//
//  Created by Codex on 07.09.2026.
//

import Foundation

struct MissionRouteRefreshContext {
    let state: NavigationRouteState
    let progress: Float
    let planets: [Planet]
    let snapshot: UniverseSceneSnapshot
}

protocol NavigationRouteMissionHandling {
    func refreshedRoute(for route: NavigationRoute,
                        context: MissionRouteRefreshContext,
                        routeBuilder: RouteBuilding) -> NavigationRoute?
    func routeProgress(linearProgress: Float,
                       route: NavigationRoute) -> Float?
}

struct MissionRouteHandler: NavigationRouteMissionHandling {
    func refreshedRoute(for route: NavigationRoute,
                        context: MissionRouteRefreshContext,
                        routeBuilder: RouteBuilding) -> NavigationRoute? {
        let state = context.state
        let progress = context.progress
        let planets = context.planets
        let snapshot = context.snapshot
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
                stateProvider: snapshot.stateProvider,
                routeProgress: progress
              )) else {
            return nil
        }

        return route.replacingPath(
            points: refreshedRoute.points,
            cumulativeDistances: refreshedRoute.cumulativeDistances,
            totalDistance: refreshedRoute.totalDistance,
            precisePoints: refreshedRoute.precisePoints, sampleProgresses: refreshedRoute.sampleProgresses,
                preciseOverviewCenter: refreshedRoute.preciseOverviewCenter,
            overviewPaddingRadius: refreshedRoute.overviewPaddingRadius,
            overviewCenter: refreshedRoute.overviewCenter
        )
    }

    private func refreshedEarthMission(route: NavigationRoute,
                                       snapshot: UniverseSceneSnapshot) -> NavigationRoute? {
        guard let center = route.missionEarthPreciseCenter, let earth = snapshot.planet(named: "Earth"),
              earth.worldPosition.x.isFinite, earth.worldPosition.y.isFinite,
              earth.worldPosition.z.isFinite else { return nil }
        let offset = earth.preciseWorldPosition - center
        return NavigationRoute(id: route.id, originName: route.originName, waypointName: route.waypointName,
                               destinationName: route.destinationName,
                                   points: route.precisePoints.map { SIMD3<Float>($0 + offset) },
                               cumulativeDistances: route.cumulativeDistances, totalDistance: route.totalDistance,
                               estimatedDuration: route.estimatedDuration,
                               overviewPaddingRadius: route.overviewPaddingRadius, overviewCenter: earth.worldPosition,
                               precisePoints: route.precisePoints.map { $0 + offset },
                               preciseOverviewCenter: earth.preciseWorldPosition, mission: route.mission,
                               starshipProfile: route.starshipProfile?.translatedPrecisely(
                                to: earth.preciseWorldPosition),
                               crew13Profile: route.crew13Profile?.translatedPrecisely(to: earth.preciseWorldPosition))
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
