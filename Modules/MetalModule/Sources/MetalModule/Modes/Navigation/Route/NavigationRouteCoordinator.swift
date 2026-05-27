//
//  NavigationRouteCoordinator.swift
//  MetalModule
//
//  Created by Codex on 11.05.2026.
//

import Foundation
import simd

/// Owns route construction, playback state, and public route snapshots for a single navigation session.
///
/// `NavigationRouteCoordinator` is necessary because route playback has a state machine separate from
/// camera behavior: preparing a route can fail, progress can pause or resume, rendering needs a stable
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
    private let snapshotPublisher: (NavigationRouteSnapshot) -> Void

    private(set) var route: NavigationRoute?
    private(set) var state: NavigationRouteState = .idle
    private var lastPublishedSnapshot: NavigationRouteSnapshot = .idle

    init(routeBuilder: RouteBuilding = RoutePathBuilder(),
         playback: RoutePlayback = RoutePlaybackController(),
         snapshotPublisher: @escaping (NavigationRouteSnapshot) -> Void) {
        self.routeBuilder = routeBuilder
        self.playback = playback
        self.snapshotPublisher = snapshotPublisher
    }

    func start(destinationName: String,
               planets: [Planet],
               snapshot: PreparedRenderSnapshot) -> Bool {
        state = .preparing
        publishSnapshot()

        guard let sunPosition = snapshot.worldPosition(ofPlanetNamed: "Sun"),
              let earthPosition = snapshot.worldPosition(ofPlanetNamed: "Earth"),
              let destinationPosition = snapshot.worldPosition(ofPlanetNamed: destinationName),
              let route = routeBuilder.makeRoute(input: RouteBuildInput(
                destinationName: destinationName,
                planets: planets,
                earthSunDirection: earthPosition - sunPosition,
                sunPosition: sunPosition,
                destinationPosition: destinationPosition,
                estimatedDuration: 12
              )) else {
            self.route = nil
            playback.cancel()
            state = .cancelled
            publishSnapshot()
            return false
        }

        self.route = route
        playback.start(duration: route.estimatedDuration)
        state = .running
        publishSnapshot()
        return true
    }

    func refresh(using transferOrbit: HohmannTransferOrbit,
                 destinationPosition: SIMD3<Float>) {
        guard let route,
              route.destinationName == transferOrbit.destinationName,
              state == .running || state == .paused || state == .completed else {
            return
        }

        let routePoints = RoutePathBuilder.makeNavigationPoints(transferOrbit: transferOrbit,
                                                                destinationPosition: destinationPosition)
        let cumulativeDistances = RoutePathBuilder.makeCumulativeDistances(points: routePoints)
        guard let totalDistance = cumulativeDistances.last,
              totalDistance > 0 else {
            return
        }

        self.route = route.replacingPath(points: routePoints,
                                         cumulativeDistances: cumulativeDistances,
                                         totalDistance: totalDistance)
    }

    func pause() {
        guard state == .running else { return }
        playback.pause()
        state = .paused
        publishSnapshot()
    }

    func resume() {
        guard state == .paused else { return }
        playback.resume()
        state = .running
        publishSnapshot()
    }

    func cancel() {
        playback.cancel()
        route = nil
        state = .cancelled
        publishSnapshot()
    }

    func update() {
        guard state == .running else { return }

        playback.update()
        if playback.isCompleted {
            state = .completed
        }
        publishSnapshot()
    }

    var renderProgress: Float {
        switch state {
        case .running, .paused, .completed:
            return playback.progress
        case .idle, .preparing, .cancelled:
            return 0
        }
    }

    var elapsedTime: TimeInterval {
        playback.elapsedTime
    }

    var isNavigationActive: Bool {
        activeRouteForRendering != nil
    }

    var currentRoutePoint: SIMD3<Float>? {
        activeRouteForRendering?.point(at: renderProgress)
    }

    var activeRouteForRendering: NavigationRoute? {
        switch state {
        case .running, .paused, .completed:
            route
        case .idle, .preparing, .cancelled:
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
                                           destinationName: nil,
                                           progress: 0,
                                           elapsedTime: 0,
                                           remainingTime: 0,
                                           estimatedDuration: 0)
        }

        let progress = state == .completed ? 1 : playback.progress
        let elapsedTime = state == .completed ? route.estimatedDuration : playback.elapsedTime
        let remainingTime = max(route.estimatedDuration - elapsedTime, 0)

        return NavigationRouteSnapshot(routeID: route.id,
                                       state: state,
                                       destinationName: route.destinationName,
                                       progress: progress,
                                       elapsedTime: elapsedTime,
                                       remainingTime: remainingTime,
                                       estimatedDuration: route.estimatedDuration)
    }
}
