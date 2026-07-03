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
    private let refreshSmoothingFactor: Float = 0.18
    private let refreshRelativeDisplacementThreshold: Float = 0.000_05
    private let refreshMinimumDisplacementThreshold: Float = 0.000_05

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

    func start(originName: String = "Earth",
               waypointName: String? = nil,
               destinationName: String,
               planets: [Planet],
               snapshot: UniverseSceneSnapshot) -> Bool {
        state = .preparing

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
                earthSunDirection: earthPosition - sunPosition,
                sunPosition: sunPosition,
                destinationPosition: destinationPosition,
                estimatedDuration: estimatedDuration(originName: originName,
                                                     destinationName: destinationName)
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

        let destinationArcSampleCount = currentDestinationArcSampleCount(
            route: route,
            transferPointCount: transferOrbit.points.count
        )
        let refreshedPoints = RoutePathBuilder.makeNavigationPoints(
            transferOrbit: transferOrbit,
            destinationPosition: destinationPosition,
            destinationArcSampleCount: destinationArcSampleCount
        )
        let routePoints: [SIMD3<Float>]
        if refreshedPoints.count == route.points.count {
            let displacement = maxDisplacement(from: route.points,
                                               to: refreshedPoints)
            let threshold = max(route.totalDistance * refreshRelativeDisplacementThreshold,
                                refreshMinimumDisplacementThreshold)
            guard displacement >= threshold else { return }
            routePoints = smoothedPoints(from: route.points,
                                         to: refreshedPoints)
        } else {
            routePoints = refreshedPoints
        }

        let cumulativeDistances = RoutePathBuilder.makeCumulativeDistances(points: routePoints)
        guard let totalDistance = cumulativeDistances.last,
              totalDistance > 0 else {
            return
        }

        self.route = route.replacingPath(points: routePoints,
                                         cumulativeDistances: cumulativeDistances,
                                         totalDistance: totalDistance)
    }

    private func currentDestinationArcSampleCount(route: NavigationRoute,
                                                  transferPointCount: Int) -> Int? {
        let destinationArcSampleCount = route.points.count - transferPointCount
        guard destinationArcSampleCount > 0 else { return nil }
        return destinationArcSampleCount
    }

    private func maxDisplacement(from currentPoints: [SIMD3<Float>],
                                 to refreshedPoints: [SIMD3<Float>]) -> Float {
        zip(currentPoints, refreshedPoints).reduce(0) { partialResult, pair in
            max(partialResult, simd_distance(pair.0, pair.1))
        }
    }

    private func smoothedPoints(from currentPoints: [SIMD3<Float>],
                                to refreshedPoints: [SIMD3<Float>]) -> [SIMD3<Float>] {
        zip(currentPoints, refreshedPoints).map { currentPoint, refreshedPoint in
            currentPoint + (refreshedPoint - currentPoint) * refreshSmoothingFactor
        }
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

    private func estimatedDuration(originName: String,
                                   destinationName: String) -> TimeInterval {
        if originName == "Earth" && destinationName == "Earth" {
            return 16
        }

        return 12
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
                                           originName: nil,
                                           waypointName: nil,
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
                                       originName: route.originName,
                                       waypointName: route.waypointName,
                                       destinationName: route.destinationName,
                                       progress: progress,
                                       elapsedTime: elapsedTime,
                                       remainingTime: remainingTime,
                                       estimatedDuration: route.estimatedDuration)
    }
}
