//
//  RoutePathBuilder.swift
//  UniverseModule
//
//  Created by Codex on 11.05.2026.
//

import Foundation
import simd

/// Builds sampled route geometry for navigation playback and rendering.
///
/// `RoutePathBuilder` is necessary because the user-facing route is not just the static transfer orbit:
/// interplanetary paths are physical intercepts and lunar missions retain their cinematic geometry.
/// It owns no runtime navigation state; it is a pure geometry builder.
///
/// Ownership:
/// - Owns only its sampling policy (`sampleCount`).
/// - Depends on `TransferSolution` for transfer-orbit geometry but does not own transfer preview
///   state or render state.
/// - Returns immutable `NavigationRoute` values to `NavigationRouteCoordinator`.
struct RoutePathBuilder: RouteBuilding { // swiftlint:disable:this type_body_length
    private let sampleCount: Int

    init(sampleCount: Int = 192) {
        self.sampleCount = sampleCount
    }

    func makeRoute(input: RouteBuildInput) -> NavigationRoute? {
        if ArtemisRouteProfile.isArtemisRoute(originName: input.originName,
                                              waypointName: input.waypointName,
                                              destinationName: input.destinationName) {
            return makeCislunarLoopRoute(input: input)
        }

        guard input.originName == "Earth" else {
            return nil
        }

        guard let transfer = input.transfer ?? (try? TransferSolution.make(
            destinationName: input.destinationName, planets: input.planets,
            departureEpoch: input.simulationTime, sunPosition: input.sunPosition,
            sampleCount: sampleCount, stateProvider: input.stateProvider
        )) else { return nil }
        let cumulativeDistances = Self.makeCumulativeDistances(precisePoints: transfer.precisePoints)
        guard let totalDistance = cumulativeDistances.last, totalDistance > 0 else { return nil }
        return NavigationRoute(originName: "Earth", destinationName: input.destinationName,
                               points: transfer.points, cumulativeDistances: cumulativeDistances,
                               totalDistance: totalDistance,
                               estimatedDuration: TransferSolution.playbackDuration,
                               overviewCenter: transfer.sunPosition, transfer: transfer,
                                   precisePoints: transfer.precisePoints)
    }

    private func makeCislunarLoopRoute(input: RouteBuildInput) -> NavigationRoute? {
        guard let originPosition = input.originPosition,
              let waypointPosition = input.waypointPosition,
              let destinationPosition = input.destinationPosition,
              simd_length_squared(waypointPosition - originPosition) > 0.000_001,
              simd_length_squared(destinationPosition - originPosition) <= 0.000_001 else {
            return nil
        }

        func precisePosition(_ name: String, fallback: SIMD3<Float>) -> SIMD3<Double>? {
            guard let provider = input.stateProvider else { return SIMD3<Double>(fallback) }
            guard let body = CelestialBodyID(rawValue: name) else { return nil }
            return (try? provider.state(for: body, at: input.simulationTime))?.scenePosition
        }
        guard let origin = precisePosition(input.originName, fallback: originPosition),
              let waypoint = precisePosition(input.waypointName ?? "Moon", fallback: waypointPosition),
              let destination = precisePosition(input.destinationName,
                                                fallback: destinationPosition) else { return nil }
        let samples = Self.makeCislunarLoopSamples(
            originPosition: .zero, waypointPosition: SIMD3<Float>(waypoint - origin),
            destinationPosition: SIMD3<Float>(destination - origin),
            originSurfaceRadius: input.originSurfaceRadius, waypointSurfaceRadius: input.waypointSurfaceRadius,
            destinationSurfaceRadius: input.destinationSurfaceRadius, sampleCount: sampleCount,
            estimatedDuration: input.estimatedDuration)
        let precisePoints = samples.points.map { origin + SIMD3<Double>($0) }
        let routePoints = precisePoints.map { SIMD3<Float>($0) }
        let cumulativeDistances = Self.makeCumulativeDistances(precisePoints: precisePoints)
        guard let totalDistance = cumulativeDistances.last,
              totalDistance > 0 else {
            return nil
        }

        return NavigationRoute(originName: input.originName,
                               waypointName: input.waypointName,
                               destinationName: input.destinationName,
                               points: routePoints,
                               cumulativeDistances: cumulativeDistances,
                               totalDistance: totalDistance,
                               estimatedDuration: input.estimatedDuration,
                               overviewPaddingRadius: ArtemisRouteProfile.overviewPaddingRadius(
                                originRadius: input.originSurfaceRadius,
                                waypointRadius: input.waypointSurfaceRadius,
                                destinationRadius: input.destinationSurfaceRadius
                               ),
                               overviewCenter: Self.cislunarLoopOverviewCenter(
                                originPosition: originPosition,
                                waypointPosition: waypointPosition,
                                destinationPosition: destinationPosition
                               ), precisePoints: precisePoints, sampleProgresses: samples.progresses,
                               preciseOverviewCenter: (origin + waypoint + destination) / 3)
    }

    static func makeCislunarLoopPoints(originPosition: SIMD3<Float>,
                                       waypointPosition: SIMD3<Float>,
                                       destinationPosition: SIMD3<Float>? = nil,
                                       originSurfaceRadius: Float = 0,
                                       waypointSurfaceRadius: Float = 0,
                                       destinationSurfaceRadius: Float = 0,
                                       sampleCount: Int = 192) -> [SIMD3<Float>] {
        makeCislunarLoopSamples(originPosition: originPosition, waypointPosition: waypointPosition,
                               destinationPosition: destinationPosition, originSurfaceRadius: originSurfaceRadius,
                               waypointSurfaceRadius: waypointSurfaceRadius,
                               destinationSurfaceRadius: destinationSurfaceRadius,
                               sampleCount: sampleCount).points
    }

    // swiftlint:disable:next function_body_length
    static func makeCislunarLoopSamples(originPosition: SIMD3<Float>,
                                        waypointPosition: SIMD3<Float>,
                                        destinationPosition: SIMD3<Float>? = nil,
                                        originSurfaceRadius: Float = 0,
                                        waypointSurfaceRadius: Float = 0,
                                        destinationSurfaceRadius: Float = 0,
                                        sampleCount: Int = 192,
                                        estimatedDuration: TimeInterval = 16) -> ArtemisPathSamples {
        let fullMajorVector = waypointPosition - originPosition
        let fullMajorDistance = simd_length(fullMajorVector)
        let majorDirection = fullMajorDistance > 0.000_001
            ? fullMajorVector / fullMajorDistance
            : SIMD3<Float>(1, 0, 0)
        let sideDirection = normalizeOrFallback(
            makeCislunarMinorAxis(majorVector: fullMajorVector, length: 1),
            fallback: SIMD3<Float>(0, 0, 1)
        )
        let sceneUp = SIMD3<Float>(0, 1, 0)
        let returnPosition = destinationPosition ?? originPosition
        let originClearance = ArtemisRouteProfile.anchorClearance(
            radius: originSurfaceRadius,
            maximumDistance: fullMajorDistance
        )
        let earthLoopRadius = max(originSurfaceRadius * ArtemisRouteProfile.earthLoopRadiusScale,
                                  fullMajorDistance * ArtemisRouteProfile.earthLoopDistanceScale,
                                  0.03)
        let lunarFlybyRadius = max(
            waypointSurfaceRadius * ArtemisRouteProfile.lunarFlybyRadiusScale,
            fullMajorDistance * ArtemisRouteProfile.lunarFlybyDistanceScale,
            0.01
        )
        let launchAnchor = originPosition + majorDirection * originClearance
        let earthLoopStart = originPosition + majorDirection * earthLoopRadius
        let earthLoopEndAngle: Float = -1.35 * .pi
        let earthLoopAxisA = majorDirection * earthLoopRadius
        let earthLoopAxisB = sideDirection * earthLoopRadius * 0.58
        let earthLoopExit = originPosition
            + earthLoopAxisA * cos(earthLoopEndAngle)
            + earthLoopAxisB * sin(earthLoopEndAngle)
        let earthLoopExitTangent = normalizeOrFallback(
            earthLoopEndAngle * (
                -earthLoopAxisA * sin(earthLoopEndAngle)
                + earthLoopAxisB * cos(earthLoopEndAngle)
            ),
            fallback: majorDirection
        )
        let earthwardDirection = -majorDirection
        let lunarFlybyEntry = waypointPosition
            + earthwardDirection * lunarFlybyRadius * 1.45
            - sideDirection * lunarFlybyRadius * 0.58
            + sceneUp * lunarFlybyRadius * 0.04
        let lunarFlybyExit = waypointPosition
            + earthwardDirection * lunarFlybyRadius * 1.42
            + sideDirection * lunarFlybyRadius * 0.62
            + sceneUp * lunarFlybyRadius * ArtemisRouteProfile.lunarFlybyTiltScale
        let lunarFlybyEntryTangent = normalizeOrFallback(
            -earthwardDirection - sideDirection * 0.22,
            fallback: -earthwardDirection
        )
        let lunarFlybyExitTangent = normalizeOrFallback(
            earthwardDirection - sideDirection * 0.24,
            fallback: earthwardDirection
        )
        let minimumCount = max(sampleCount, 48)
        let earthLoopCount = max(10, Int(Float(minimumCount) * ArtemisRouteProfile.earthLoopSampleRatio))
        let outboundCount = max(16, Int(Float(minimumCount) * ArtemisRouteProfile.outboundSampleRatio))
        let lunarLoopCount = max(24, Int(Float(minimumCount) * ArtemisRouteProfile.lunarFlybySampleRatio))
        let launchCount = max(5, Int(Float(minimumCount) * 0.08))
        let returnCount = max(16, minimumCount - launchCount - earthLoopCount - outboundCount - lunarLoopCount)
        let outboundControlScale = max(fullMajorDistance, 0.1)
        let lunarFlybyEntryHandleScale = max(lunarFlybyRadius * 2.8, outboundControlScale * 0.1)
        let lunarFlybyExitHandleScale = max(lunarFlybyRadius * 2.6, outboundControlScale * 0.09)

        let launchPoints = quadraticBezierPoints(
            start: launchAnchor,
            control: earthLoopStart
                + sideDirection * earthLoopRadius * 0.38,
            end: earthLoopStart,
            count: launchCount
        )
        let earthLoopPoints = ellipticalArcPoints(
            center: originPosition,
            axisA: earthLoopAxisA,
            axisB: earthLoopAxisB,
            angles: (start: 0, end: earthLoopEndAngle),
            count: earthLoopCount
        )
        let earthLoopEnd = earthLoopPoints.last ?? earthLoopExit
        let outboundPoints = cubicBezierPoints(
            start: earthLoopEnd,
            controlA: earthLoopEnd
                + earthLoopExitTangent * outboundControlScale * 0.22,
            controlB: lunarFlybyEntry
                - lunarFlybyEntryTangent * lunarFlybyEntryHandleScale,
            end: lunarFlybyEntry,
            count: outboundCount
        )
        let lunarLoopPoints = cubicBezierPoints(
            start: lunarFlybyEntry,
            controlA: lunarFlybyEntry
                + lunarFlybyEntryTangent * lunarFlybyEntryHandleScale,
            controlB: lunarFlybyExit
                - lunarFlybyExitTangent * lunarFlybyExitHandleScale,
            end: lunarFlybyExit,
            count: lunarLoopCount
        )
        let lunarLoopEnd = lunarLoopPoints.last ?? lunarFlybyExit
        let returnPoints = ArtemisReturnPath(center: returnPosition,
                                             surfaceRadius: destinationSurfaceRadius,
                                             majorDirection: majorDirection,
                                             sideDirection: sideDirection,
                                             controlScale: outboundControlScale).makePoints(
            start: lunarLoopEnd,
            controlA: lunarLoopEnd + lunarFlybyExitTangent * lunarFlybyExitHandleScale,
            sampleCount: returnCount
        )

        let departureEnd = ArtemisRouteProfile.openingPhaseEnd(estimatedDuration: estimatedDuration)
        var samples = ArtemisPathSamples()
        samples.append(launchPoints, from: 0, to: departureEnd * 0.25)
        samples.append(earthLoopPoints, from: departureEnd * 0.25, to: departureEnd)
        samples.append(outboundPoints, from: departureEnd, to: ArtemisRouteProfile.lunarFlybyCloseUpStartProgress)
        // Date the actual closest sampled point, not an arc-length fraction of the whole route.
        let closest = lunarLoopPoints.indices.min {
            simd_distance_squared(lunarLoopPoints[$0], waypointPosition)
                < simd_distance_squared(lunarLoopPoints[$1], waypointPosition)
        } ?? lunarLoopPoints.count / 2
        samples.append(Array(lunarLoopPoints[...closest]),
                       from: ArtemisRouteProfile.lunarFlybyCloseUpStartProgress,
                       to: ArtemisRouteProfile.lunarEncounterProgress)
        samples.append(Array(lunarLoopPoints[closest...]),
                       from: ArtemisRouteProfile.lunarEncounterProgress,
                       to: ArtemisRouteProfile.lunarFlybyCloseUpEndProgress)
        samples.append(returnPoints, from: ArtemisRouteProfile.lunarFlybyCloseUpEndProgress, to: 1)
        return samples
    }

    static func predictedArtemisWaypointPosition(input: RouteBuildInput) -> SIMD3<Float>? {
        guard let waypointName = input.waypointName else {
            return nil
        }

        return predictedWorldPosition(
            ofPlanetNamed: waypointName,
            planets: input.planets,
            stateProvider: input.stateProvider,
            simulationTime: predictionSimulationTime(
                targetProgress: ArtemisRouteProfile.lunarEncounterProgress,
                input: input
            )
        )
    }

    static func predictedArtemisDestinationPosition(input: RouteBuildInput) -> SIMD3<Float>? {
        predictedWorldPosition(
            ofPlanetNamed: input.destinationName,
            planets: input.planets,
            stateProvider: input.stateProvider,
            simulationTime: predictionSimulationTime(targetProgress: 1, input: input)
        )
    }

    static func makeCumulativeDistances(points: [SIMD3<Float>]) -> [Float] {
        makeCumulativeDistances(precisePoints: points.map { SIMD3<Double>($0) })
    }

    static func makeCumulativeDistances(precisePoints points: [SIMD3<Double>]) -> [Float] {
        guard let first = points.first else { return [] }

        var distances: [Float] = [0]
        distances.reserveCapacity(points.count)
        var previousPoint = first
        var runningDistance: Float = 0

        for point in points.dropFirst() {
            runningDistance += Float(simd_distance(previousPoint, point))
            distances.append(runningDistance)
            previousPoint = point
        }

        return distances
    }

}
