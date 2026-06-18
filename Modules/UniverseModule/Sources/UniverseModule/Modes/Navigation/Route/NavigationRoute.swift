//
//  NavigationRoute.swift
//  UniverseModule
//
//  Created by Codex on 11.05.2026.
//

import Foundation
import simd

/// Public lifecycle state for route navigation.
///
/// This enum is the stable state surface consumed by UI and resource facades. It exists separately from
/// render state so navigation controls can observe lifecycle changes without depending on route geometry.
public enum NavigationRouteState: Sendable, Equatable {
    case idle
    case preparing
    case running
    case paused
    case completed
    case cancelled
}

/// Immutable route geometry and timing metadata for one navigation session.
///
/// `NavigationRoute` is necessary as the shared data model between route playback, camera follow logic,
/// and route rendering. It stores sampled world-space points plus cumulative distances so progress can be
/// converted into a current route point without recalculating geometry every frame.
///
/// Ownership:
/// - Created by `RouteBuilding` implementations and owned by `NavigationRouteCoordinator`.
/// - Read by `NavigationController` for camera commits and by `RouteRenderer` through render state.
/// - Does not own playback time, camera state, or renderer resources.
public struct NavigationRoute: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let originName: String
    public let destinationName: String
    public let points: [SIMD3<Float>]
    public let cumulativeDistances: [Float]
    public let totalDistance: Float
    public let estimatedDuration: TimeInterval

    init(id: UUID = UUID(),
         originName: String,
         destinationName: String,
         points: [SIMD3<Float>],
         cumulativeDistances: [Float],
         totalDistance: Float,
         estimatedDuration: TimeInterval) {
        self.id = id
        self.originName = originName
        self.destinationName = destinationName
        self.points = points
        self.cumulativeDistances = cumulativeDistances
        self.totalDistance = totalDistance
        self.estimatedDuration = estimatedDuration
    }

    public func point(at progress: Float) -> SIMD3<Float>? {
        guard let first = points.first,
              points.count == cumulativeDistances.count else {
            return nil
        }
        guard totalDistance > 0 else { return first }

        let clampedProgress = min(max(progress, 0), 1)
        let targetDistance = totalDistance * clampedProgress

        if targetDistance <= 0 {
            return first
        }
        if targetDistance >= totalDistance {
            return points.last
        }

        guard let upperIndex = cumulativeDistances.firstIndex(where: { $0 >= targetDistance }),
              upperIndex > 0 else {
            return first
        }

        let lowerIndex = upperIndex - 1
        let lowerDistance = cumulativeDistances[lowerIndex]
        let upperDistance = cumulativeDistances[upperIndex]
        let segmentDistance = max(upperDistance - lowerDistance, .leastNonzeroMagnitude)
        let segmentProgress = (targetDistance - lowerDistance) / segmentDistance

        return points[lowerIndex] + (points[upperIndex] - points[lowerIndex]) * segmentProgress
    }

    func replacingPath(points: [SIMD3<Float>],
                       cumulativeDistances: [Float],
                       totalDistance: Float) -> NavigationRoute {
        NavigationRoute(id: id,
                        originName: originName,
                        destinationName: destinationName,
                        points: points,
                        cumulativeDistances: cumulativeDistances,
                        totalDistance: totalDistance,
                        estimatedDuration: estimatedDuration)
    }
}

/// Public, lightweight snapshot of navigation state.
///
/// `NavigationRouteSnapshot` is necessary because views and facades need navigation progress and timing
/// without depending on `NavigationRoute` geometry or coordinator internals. It is published by
/// `NavigationRouteCoordinator` and stored by `UniverseModuleResources`.
///
/// Ownership:
/// - Produced by the route coordinator whenever lifecycle/progress state changes.
/// - Consumed outside the navigation mode as immutable value data.
/// - Does not grant access to mutable route or camera ownership.
public struct NavigationRouteSnapshot: Sendable, Equatable {
    public let routeID: UUID?
    public let state: NavigationRouteState
    public let destinationName: String?
    public let progress: Float
    public let elapsedTime: TimeInterval
    public let remainingTime: TimeInterval
    public let estimatedDuration: TimeInterval

    public static let idle = NavigationRouteSnapshot(routeID: nil,
                                                     state: .idle,
                                                     destinationName: nil,
                                                     progress: 0,
                                                     elapsedTime: 0,
                                                     remainingTime: 0,
                                                     estimatedDuration: 0)
}
