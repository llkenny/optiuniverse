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
    case completed
    case failed
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
    let precisePoints: [SIMD3<Double>]
    let sampleProgresses: [Float]?
    public let cumulativeDistances: [Float]
    public let totalDistance: Float
    public let estimatedDuration: TimeInterval
    let mission: MissionFlightPlan?
    let starshipProfile: StarshipRouteProfile?
    let crew13Profile: Crew13RouteProfile?

    var hasMissionVehicles: Bool { starshipProfile != nil || crew13Profile != nil }
    var missionEarthCenter: SIMD3<Float>? { starshipProfile?.center ?? crew13Profile?.center }
    var missionEarthPreciseCenter: SIMD3<Double>? { starshipProfile?.preciseCenter ?? crew13Profile?.preciseCenter }
    var missionEarthRadius: Float? { starshipProfile?.radius ?? crew13Profile?.radius }
    let transfer: TransferSolution?
    let overviewPaddingRadius: Float
    let overviewCenter: SIMD3<Float>
    let preciseOverviewCenter: SIMD3<Double>

    init(id: UUID = UUID(),
         originName: String,
         waypointName: String? = nil,
         destinationName: String,
         points: [SIMD3<Float>],
         cumulativeDistances: [Float],
         totalDistance: Float,
         estimatedDuration: TimeInterval,
         overviewPaddingRadius: Float = 0,
         overviewCenter: SIMD3<Float>? = nil,
         transfer: TransferSolution? = nil,
         precisePoints: [SIMD3<Double>]? = nil,
         sampleProgresses: [Float]? = nil,
         preciseOverviewCenter: SIMD3<Double>? = nil,
         mission: MissionFlightPlan? = nil,
         starshipProfile: StarshipRouteProfile? = nil,
         crew13Profile: Crew13RouteProfile? = nil) {
        self.mission = mission
        self.starshipProfile = starshipProfile
        self.crew13Profile = crew13Profile
        self.transfer = transfer
        self.id = id
        self.originName = originName
        self.waypointName = waypointName
        self.destinationName = destinationName
        self.points = points
        self.precisePoints = precisePoints ?? points.map { SIMD3<Double>($0) }
        self.sampleProgresses = sampleProgresses
        self.cumulativeDistances = cumulativeDistances
        self.totalDistance = totalDistance
        self.estimatedDuration = estimatedDuration
        self.overviewPaddingRadius = overviewPaddingRadius
        self.overviewCenter = overviewCenter ?? points.first ?? .zero
        self.preciseOverviewCenter = preciseOverviewCenter ?? SIMD3<Double>(self.overviewCenter)
    }

    public func point(at progress: Float) -> SIMD3<Float>? {
        if let crew13Profile { return crew13Profile.dragonPosition(time: Double(progress) * estimatedDuration) }
        if let starshipProfile { return starshipProfile.shipPosition(time: Double(progress) * 60) }
        if let transfer { return transfer.position(at: Double(progress)) }
        return point(atDistance: distance(at: progress))
    }

    func precisePoint(at progress: Float) -> SIMD3<Double>? {
        if let crew13Profile { return crew13Profile.precisePosition(time: Double(progress) * estimatedDuration) }
        if let starshipProfile { return starshipProfile.precisePosition(time: Double(progress) * estimatedDuration) }
        if let transfer { return transfer.precisePosition(at: Double(progress)) }
        guard precisePoints.count == cumulativeDistances.count, let first = precisePoints.first else { return nil }
        let target = distance(at: progress)
        guard target > 0, totalDistance > 0 else { return first }
        guard let upper = cumulativeDistances.firstIndex(where: { $0 >= target }), upper > 0 else { return precisePoints.last }
        let fraction = Double((target - cumulativeDistances[upper-1]) /
                              max(cumulativeDistances[upper] - cumulativeDistances[upper-1], .leastNonzeroMagnitude))
        return precisePoints[upper-1] + (precisePoints[upper] - precisePoints[upper-1]) * fraction
    }

    func preciseRenderPoints(through progress: Float) -> [SIMD3<Double>] {
        var visibleProgress = progress
        if ArtemisRouteProfile.isArtemisRoute(self) {
            let opening = ArtemisRouteProfile.openingPhaseEnd(estimatedDuration: estimatedDuration)
            guard progress < opening else { return precisePoints }
            visibleProgress = max(progress, ArtemisRouteProfile.easedOpeningProgress(routeProgress: progress,
                                                                                     estimatedDuration: estimatedDuration))
        } else if !hasMissionVehicles { return precisePoints }
        guard precisePoints.count == cumulativeDistances.count, let first = precisePoints.first else { return [] }
        guard visibleProgress > 0 else { return [first] }
        guard visibleProgress < 1 else { return precisePoints }
        let target = distance(at: visibleProgress)
        var prefix = [first]
        for upper in 1..<precisePoints.count {
            if cumulativeDistances[upper] < target { prefix.append(precisePoints[upper]); continue }
            if let point = precisePoint(at: visibleProgress) { prefix.append(point) }
            break
        }
        return prefix
    }

    func distance(at progress: Float) -> Float {
        guard totalDistance.isFinite, totalDistance > 0 else { return 0 }
        let clampedProgress = min(max(progress, 0), 1)
        if let sampleProgresses, sampleProgresses.count == cumulativeDistances.count {
            guard let upper = sampleProgresses.firstIndex(where: { $0 >= clampedProgress }), upper > 0 else {
                return clampedProgress <= 0 ? 0 : totalDistance
            }
            let fraction = (clampedProgress - sampleProgresses[upper - 1])
                / max(sampleProgresses[upper] - sampleProgresses[upper - 1], .leastNonzeroMagnitude)
            return cumulativeDistances[upper - 1]
                + (cumulativeDistances[upper] - cumulativeDistances[upper - 1]) * fraction
        }
        if transfer != nil || hasMissionVehicles, points.count > 1 {
            let sample = clampedProgress * Float(points.count - 1)
            let lower = min(Int(sample), points.count - 2)
            let fraction = sample - Float(lower)
            return cumulativeDistances[lower] + fraction * (cumulativeDistances[lower + 1] - cumulativeDistances[lower])
        }
        return totalDistance * clampedProgress
    }

    func remainingDistance(at progress: Float) -> Float {
        max(totalDistance - distance(at: progress), 0)
    }

    func motionDirection(at progress: Float) -> SIMD3<Float>? {
        if let transfer,
           let state = try? transfer.trajectory.state(after: Double(min(1, max(0, progress))) * transfer.flightDuration) {
            return normalize(OrbitalState.scenePosition(state.velocity))
        }
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
            } else if let point = point(at: progress) {
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

    func withMission(_ mission: MissionFlightPlan?) -> NavigationRoute {
        NavigationRoute(id: id, originName: originName, waypointName: waypointName,
                        destinationName: destinationName, points: points,
                        cumulativeDistances: cumulativeDistances, totalDistance: totalDistance,
                        estimatedDuration: estimatedDuration, overviewPaddingRadius: overviewPaddingRadius,
                        overviewCenter: overviewCenter, transfer: transfer, precisePoints: precisePoints,
                        sampleProgresses: sampleProgresses, preciseOverviewCenter: preciseOverviewCenter, mission: mission,
                        starshipProfile: starshipProfile, crew13Profile: crew13Profile)
    }

    func replacingPath(points: [SIMD3<Float>],
                       cumulativeDistances: [Float],
                       totalDistance: Float,
                       precisePoints: [SIMD3<Double>]? = nil,
                       sampleProgresses: [Float]? = nil,
                       preciseOverviewCenter: SIMD3<Double>? = nil,
                       overviewPaddingRadius: Float? = nil,
                       overviewCenter: SIMD3<Float>? = nil) -> NavigationRoute {
        NavigationRoute(id: id,
                        originName: originName,
                        waypointName: waypointName,
                        destinationName: destinationName,
                        points: points,
                        cumulativeDistances: cumulativeDistances,
                        totalDistance: totalDistance,
                        estimatedDuration: estimatedDuration,
                        overviewPaddingRadius: overviewPaddingRadius ?? self.overviewPaddingRadius,
                        overviewCenter: overviewCenter ?? self.overviewCenter,
                        transfer: transfer, precisePoints: precisePoints,
                        sampleProgresses: sampleProgresses ?? self.sampleProgresses,
                        preciseOverviewCenter: preciseOverviewCenter ?? self.preciseOverviewCenter, mission: mission,
                        starshipProfile: starshipProfile, crew13Profile: crew13Profile)
    }
}
