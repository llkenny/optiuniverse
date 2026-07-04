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
    public let waypointName: String?
    public let destinationName: String
    public let points: [SIMD3<Float>]
    public let cumulativeDistances: [Float]
    public let totalDistance: Float
    public let estimatedDuration: TimeInterval
    let overviewPaddingRadius: Float
    let overviewCenter: SIMD3<Float>

    init(id: UUID = UUID(),
         originName: String,
         waypointName: String? = nil,
         destinationName: String,
         points: [SIMD3<Float>],
         cumulativeDistances: [Float],
         totalDistance: Float,
         estimatedDuration: TimeInterval,
         overviewPaddingRadius: Float = 0,
         overviewCenter: SIMD3<Float>? = nil) {
        self.id = id
        self.originName = originName
        self.waypointName = waypointName
        self.destinationName = destinationName
        self.points = points
        self.cumulativeDistances = cumulativeDistances
        self.totalDistance = totalDistance
        self.estimatedDuration = estimatedDuration
        self.overviewPaddingRadius = overviewPaddingRadius
        self.overviewCenter = overviewCenter ?? points.first ?? .zero
    }

    public func point(at progress: Float) -> SIMD3<Float>? {
        point(atDistance: distance(at: progress))
    }

    func distance(at progress: Float) -> Float {
        guard totalDistance.isFinite, totalDistance > 0 else { return 0 }
        let clampedProgress = min(max(progress, 0), 1)
        return totalDistance * clampedProgress
    }

    func remainingDistance(at progress: Float) -> Float {
        max(totalDistance - distance(at: progress), 0)
    }

    func motionDirection(at progress: Float) -> SIMD3<Float>? {
        guard points.count >= 2,
              points.count == cumulativeDistances.count else {
            return nil
        }

        let targetDistance = distance(at: progress)
        let epsilon: Float = 0.000_001

        for upperIndex in 1..<points.count where cumulativeDistances[upperIndex] > targetDistance + epsilon {
            let direction = points[upperIndex] - points[upperIndex - 1]
            if simd_length_squared(direction) > epsilon {
                return normalize(direction)
            }
        }

        for upperIndex in stride(from: points.count - 1, through: 1, by: -1) {
            let direction = points[upperIndex] - points[upperIndex - 1]
            if simd_length_squared(direction) > epsilon {
                return normalize(direction)
            }
        }

        return nil
    }

    func lookAheadPoint(at progress: Float,
                        distance lookAheadDistance: Float) -> SIMD3<Float>? {
        guard lookAheadDistance.isFinite else {
            return point(at: progress)
        }

        let targetDistance = min(distance(at: progress) + max(lookAheadDistance, 0), totalDistance)
        return point(atDistance: targetDistance)
    }

    func prefixPoints(through progress: Float) -> [SIMD3<Float>] {
        guard let first = points.first,
              points.count == cumulativeDistances.count else {
            return []
        }
        guard totalDistance > 0 else { return [first] }

        let clampedProgress = min(max(progress, 0), 1)
        guard clampedProgress > 0 else { return [first] }
        guard clampedProgress < 1 else { return points }

        let targetDistance = distance(at: clampedProgress)
        let epsilon: Float = 0.000_001
        var prefix = [first]
        prefix.reserveCapacity(points.count)

        for upperIndex in 1..<points.count {
            let upperDistance = cumulativeDistances[upperIndex]
            if upperDistance < targetDistance - epsilon {
                prefix.append(points[upperIndex])
                continue
            }

            if abs(upperDistance - targetDistance) <= epsilon {
                prefix.append(points[upperIndex])
            } else if let point = point(atDistance: targetDistance) {
                prefix.append(point)
            }
            break
        }

        return prefix
    }

    private func point(atDistance targetDistance: Float) -> SIMD3<Float>? {
        guard let first = points.first,
              points.count == cumulativeDistances.count else {
            return nil
        }
        guard totalDistance > 0 else { return first }

        let clampedDistance = min(max(targetDistance, 0), totalDistance)

        if clampedDistance <= 0 {
            return first
        }
        if clampedDistance >= totalDistance {
            return points.last
        }

        guard let upperIndex = cumulativeDistances.firstIndex(where: { $0 >= clampedDistance }),
              upperIndex > 0 else {
            return first
        }

        let lowerIndex = upperIndex - 1
        let lowerDistance = cumulativeDistances[lowerIndex]
        let upperDistance = cumulativeDistances[upperIndex]
        let segmentDistance = max(upperDistance - lowerDistance, .leastNonzeroMagnitude)
        let segmentProgress = (clampedDistance - lowerDistance) / segmentDistance

        return points[lowerIndex] + (points[upperIndex] - points[lowerIndex]) * segmentProgress
    }

    func replacingPath(points: [SIMD3<Float>],
                       cumulativeDistances: [Float],
                       totalDistance: Float) -> NavigationRoute {
        NavigationRoute(id: id,
                        originName: originName,
                        waypointName: waypointName,
                        destinationName: destinationName,
                        points: points,
                        cumulativeDistances: cumulativeDistances,
                        totalDistance: totalDistance,
                        estimatedDuration: estimatedDuration,
                        overviewPaddingRadius: overviewPaddingRadius,
                        overviewCenter: overviewCenter)
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
    public let originName: String?
    public let waypointName: String?
    public let destinationName: String?
    public let progress: Float
    public let elapsedTime: TimeInterval
    public let remainingTime: TimeInterval
    public let estimatedDuration: TimeInterval

    public static let idle = NavigationRouteSnapshot(routeID: nil,
                                                     state: .idle,
                                                     originName: nil,
                                                     waypointName: nil,
                                                     destinationName: nil,
                                                     progress: 0,
                                                     elapsedTime: 0,
                                                     remainingTime: 0,
                                                     estimatedDuration: 0)
}
