//
//  NavigationRouteCoordinator.swift
//  UniverseModule
//
//  Created by Codex on 11.05.2026.
//

import Foundation
import simd

/// Owns route construction, playback state, and public route snapshots for a single navigation session.
///
/// `NavigationRouteCoordinator` is necessary because route playback has a state machine separate from
/// camera behavior: preparing a route can fail, playback advances in time, rendering needs a stable
/// active route, and UI state should only publish when the route snapshot actually changes.
///
/// Ownership:
/// - Owns the current `NavigationRoute`, `NavigationRouteState`, and last published route snapshot.
/// - Owns injected route-building and playback collaborators through `RouteBuilding` and
///   `RoutePlayback` so tests can replace geometry or time behavior.
/// - Does not own camera state, render matrices, or transfer-orbit preview state.
/// - Is owned by `NavigationController`, which decides when route lifecycle operations are invoked.
@MainActor
final class NavigationRouteCoordinator {

    private let routeBuilder: RouteBuilding
    private let playback: RoutePlayback
    private let missionRouteHandler: any NavigationRouteMissionHandling
    private let snapshotPublisher: (NavigationRouteSnapshot) -> Void

    private(set) var route: NavigationRoute?
    private(set) var state: NavigationRouteState = .idle
    private var transferElapsedTime: Double = 0
    private var requestedDestination: String?
    private var failure: TransferFailure?
    private var lastPublishedSnapshot: NavigationRouteSnapshot = .idle

    init(routeBuilder: RouteBuilding = RoutePathBuilder(),
         playback: RoutePlayback = RoutePlaybackController(),
         missionRouteHandler: any NavigationRouteMissionHandling = MissionRouteHandler(),
         snapshotPublisher: @escaping (NavigationRouteSnapshot) -> Void) {
        self.routeBuilder = routeBuilder
        self.playback = playback
        self.missionRouteHandler = missionRouteHandler
        self.snapshotPublisher = snapshotPublisher
    }

    func start(originName: String = "Earth",
               waypointName: String? = nil,
               destinationName: String,
               planets: [Planet],
               snapshot: UniverseSceneSnapshot) -> Bool {
        requestedDestination = destinationName
        state = .preparing
        failure = nil
        transferElapsedTime = 0
        var transfer: TransferSolution?
        if !ArtemisRouteProfile.isArtemisRoute(originName: originName, waypointName: waypointName,
                                               destinationName: destinationName) {
            do {
                guard originName == "Earth", waypointName == nil else { throw TransferFailure.invalidGeometry }
                transfer = try TransferSolution.make(destinationName: destinationName, planets: planets,
                                                      departureEpoch: snapshot.simulationTime)
            } catch {
                self.route = nil
                playback.cancel()
                failure = (error as? TransferFailure) ?? .didNotConverge
                state = .failed
                publishSnapshot()
                return false
            }
        }

        guard let sunPosition = snapshot.worldPosition(ofPlanetNamed: "Sun"),
              let earthPosition = snapshot.worldPosition(ofPlanetNamed: "Earth"),
              let originPosition = snapshot.worldPosition(ofPlanetNamed: originName),
              let destinationPosition = snapshot.worldPosition(ofPlanetNamed: destinationName),
              let route = routeBuilder.makeRoute(input: RouteBuildInput(
                originName: originName,
                waypointName: waypointName,
                destinationName: destinationName,
                planets: planets,
                originPosition: originPosition,
                waypointPosition: waypointName.flatMap { snapshot.worldPosition(ofPlanetNamed: $0) },
                originSurfaceRadius: snapshot.surfaceRadius(ofPlanetNamed: originName) ?? 0,
                waypointSurfaceRadius: waypointName.flatMap {
                    snapshot.surfaceRadius(ofPlanetNamed: $0)
                } ?? 0,
                destinationSurfaceRadius: snapshot.surfaceRadius(ofPlanetNamed: destinationName) ?? 0,
                earthSunDirection: earthPosition - sunPosition,
                sunPosition: sunPosition,
                destinationPosition: destinationPosition,
                estimatedDuration: estimatedDuration(originName: originName,
                                                     destinationName: destinationName),
                simulationTime: snapshot.simulationTime,
                transfer: transfer,
                routeProgress: 0
              )) else {
            self.route = nil
            playback.cancel()
            state = .failed
            failure = .invalidGeometry
            publishSnapshot()
            return false
        }

        self.route = route
        playback.start(duration: route.estimatedDuration)
        state = .running
        publishSnapshot()
        return true
    }

    func refreshRoute(planets: [Planet],
                      snapshot: UniverseSceneSnapshot) {
        guard let route,
              let refreshedRoute = missionRouteHandler.refreshedRoute(
                for: route,
                state: state,
                progress: renderProgress,
                planets: planets,
                snapshot: snapshot,
                routeBuilder: routeBuilder
              ) else {
            return
        }

        self.route = refreshedRoute
    }

    func cancel() {
        failure = nil
        requestedDestination = nil
        playback.cancel()
        route = nil
        state = .cancelled
        publishSnapshot()
    }

    func update(simulationTime: Double? = nil, delta: Double = 0) {
        guard state == .running else { return }

        if let transfer = route?.transfer {
            guard let simulationTime, simulationTime >= transfer.departureEpoch else { return }
            let progress = min(1, max(0, (simulationTime - transfer.departureEpoch) / transfer.flightDuration))
            transferElapsedTime = max(transferElapsedTime, progress * TransferSolution.playbackDuration)
            if simulationTime >= transfer.arrivalEpoch { state = .completed }
        } else {
            playback.advance(by: delta)
            playback.update()
        }
        if route?.transfer == nil && playback.isCompleted {
            state = .completed
        }
        publishSnapshot()
    }

    var renderProgress: Float {
        switch state {
        case .running, .completed:
            return routeProgress(linearProgress: route?.transfer == nil ? playback.progress : Float(transferElapsedTime / TransferSolution.playbackDuration))
        case .idle, .preparing, .cancelled, .failed:
            return 0
        }
    }

    var elapsedTime: TimeInterval {
        route?.transfer == nil ? playback.elapsedTime : transferElapsedTime
    }

    var isNavigationActive: Bool {
        activeRouteForRendering != nil
    }

    var currentRoutePoint: SIMD3<Float>? {
        activeRouteForRendering?.point(at: renderProgress)
    }

    private func estimatedDuration(originName: String,
                                   destinationName: String) -> TimeInterval {
        if originName == "Earth" && destinationName == "Earth" {
            return 16
        }

        return 12
    }

    private func routeProgress(linearProgress: Float) -> Float {
        guard let route,
              let missionProgress = missionRouteHandler.routeProgress(
                linearProgress: linearProgress,
                route: route
              ) else {
            return linearProgress
        }

        return missionProgress
    }

    var activeRouteForRendering: NavigationRoute? {
        switch state {
        case .running, .completed:
            route
        case .idle, .preparing, .cancelled, .failed:
            nil
        }
    }

    private func publishSnapshot() {
        let snapshot = makeSnapshot()
        guard snapshot != lastPublishedSnapshot else { return }

        lastPublishedSnapshot = snapshot
        snapshotPublisher(snapshot)
    }

    private func makeSnapshot() -> NavigationRouteSnapshot {
        guard let route else {
            return NavigationRouteSnapshot(routeID: nil,
                                           state: state,
                                           originName: nil,
                                           waypointName: nil,
                                           destinationName: requestedDestination,
                                           progress: 0,
                                           elapsedTime: 0,
                                           remainingTime: 0,
                                           estimatedDuration: 0,
                                           failure: failure)
        }

        let progress = state == .completed ? 1 : renderProgress
        let elapsedTime = state == .completed ? route.estimatedDuration : self.elapsedTime
        let remainingTime = max(route.estimatedDuration - elapsedTime, 0)

        return NavigationRouteSnapshot(routeID: route.id,
                                       state: state,
                                       originName: route.originName,
                                       waypointName: route.waypointName,
                                       destinationName: route.destinationName,
                                       progress: progress,
                                       elapsedTime: elapsedTime,
                                       remainingTime: remainingTime,
                                       estimatedDuration: route.estimatedDuration,
                                       physicalFlightDuration: route.transfer?.flightDuration)
    }
}
