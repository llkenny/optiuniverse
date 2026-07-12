//
//  RoutePathBuilder.swift
//  UniverseModule
//
//  Created by Codex on 11.05.2026.
//

import Foundation
import simd

/// Immutable input bundle for route path construction.
///
/// The builder needs positions and planet metadata from a prepared scene snapshot, but it should not own
/// that snapshot or reach back into render systems. This value defines the complete data dependency for
/// route geometry creation.
struct RouteBuildInput {
    let originName: String
    let waypointName: String?
    let destinationName: String
    let planets: [Planet]
    let originPosition: SIMD3<Float>?
    let waypointPosition: SIMD3<Float>?
    let originSurfaceRadius: Float
    let waypointSurfaceRadius: Float
    let destinationSurfaceRadius: Float
    let earthSunDirection: SIMD3<Float>
    let sunPosition: SIMD3<Float>
    let destinationPosition: SIMD3<Float>?
    let estimatedDuration: TimeInterval
    let simulationTime: Float
    let routeProgress: Float

    init(originName: String = "Earth",
         waypointName: String? = nil,
         destinationName: String,
         planets: [Planet],
         originPosition: SIMD3<Float>? = nil,
         waypointPosition: SIMD3<Float>? = nil,
         originSurfaceRadius: Float = 0,
         waypointSurfaceRadius: Float = 0,
         destinationSurfaceRadius: Float = 0,
         earthSunDirection: SIMD3<Float>,
         sunPosition: SIMD3<Float>,
         destinationPosition: SIMD3<Float>?,
         estimatedDuration: TimeInterval,
         simulationTime: Float = 0,
         routeProgress: Float = 0) {
        self.originName = originName
        self.waypointName = waypointName
        self.destinationName = destinationName
        self.planets = planets
        self.originPosition = originPosition
        self.waypointPosition = waypointPosition
        self.originSurfaceRadius = originSurfaceRadius
        self.waypointSurfaceRadius = waypointSurfaceRadius
        self.destinationSurfaceRadius = destinationSurfaceRadius
        self.earthSunDirection = earthSunDirection
        self.sunPosition = sunPosition
        self.destinationPosition = destinationPosition
        self.estimatedDuration = estimatedDuration
        self.simulationTime = simulationTime
        self.routeProgress = routeProgress
    }
}

/// Route geometry construction boundary.
///
/// `NavigationRouteCoordinator` depends on this protocol so route-building policy can vary independently
/// from playback and state publication. The default implementation uses Hohmann transfer geometry, while
/// tests can inject simpler deterministic builders.
protocol RouteBuilding {
    func makeRoute(input: RouteBuildInput) -> NavigationRoute?
}

/// Builds sampled route geometry for navigation playback and rendering.
///
/// `RoutePathBuilder` is necessary because the user-facing route is not just the static transfer orbit:
/// it also includes a short destination-orbit arc so the animated route can visibly meet the current
/// destination position. It owns no runtime navigation state; it is a pure geometry builder.
///
/// Ownership:
/// - Owns only its sampling policy (`sampleCount`).
/// - Depends on `HohmannTransferOrbit` for transfer-orbit geometry but does not own transfer preview
///   state or render state.
/// - Returns immutable `NavigationRoute` values to `NavigationRouteCoordinator`.
// swiftlint:disable:next type_body_length
struct RoutePathBuilder: RouteBuilding {
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

        guard let transferOrbit = HohmannTransferOrbit.make(destinationName: input.destinationName,
                                                            planets: input.planets,
                                                            earthSunDirection: input.earthSunDirection,
                                                            sunPosition: input.sunPosition,
                                                            sampleCount: sampleCount),
              transferOrbit.points.count >= 2 else {
            return nil
        }

        let routePoints = Self.makeNavigationPoints(transferOrbit: transferOrbit,
                                                    destinationPosition: input.destinationPosition)
        let cumulativeDistances = Self.makeCumulativeDistances(points: routePoints)
        guard let totalDistance = cumulativeDistances.last,
              totalDistance > 0 else {
            return nil
        }

        return NavigationRoute(originName: "Earth",
                               destinationName: input.destinationName,
                               points: routePoints,
                               cumulativeDistances: cumulativeDistances,
                               totalDistance: totalDistance,
                               estimatedDuration: input.estimatedDuration,
                               overviewCenter: transferOrbit.sunPosition)
    }

    private func makeCislunarLoopRoute(input: RouteBuildInput) -> NavigationRoute? {
        guard let originPosition = input.originPosition,
              let waypointPosition = input.waypointPosition,
              let destinationPosition = input.destinationPosition,
              simd_length_squared(waypointPosition - originPosition) > 0.000_001,
              simd_length_squared(destinationPosition - originPosition) <= 0.000_001 else {
            return nil
        }

        let routePoints = Self.makeCislunarLoopPoints(originPosition: originPosition,
                                                      waypointPosition: waypointPosition,
                                                      destinationPosition: destinationPosition,
                                                      originSurfaceRadius: input.originSurfaceRadius,
                                                      waypointSurfaceRadius: input.waypointSurfaceRadius,
                                                      destinationSurfaceRadius: input.destinationSurfaceRadius,
                                                      sampleCount: sampleCount)
        let cumulativeDistances = Self.makeCumulativeDistances(points: routePoints)
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
                               ))
    }

    static func makeNavigationPoints(transferOrbit: HohmannTransferOrbit,
                                     destinationPosition: SIMD3<Float>?,
                                     destinationArcSampleCount: Int? = nil) -> [SIMD3<Float>] {
        guard let destinationPosition,
              let transferEndpoint = transferOrbit.points.last else {
            return transferOrbit.points
        }

        let sunPosition = transferOrbit.sunPosition
        let endpointVector = transferEndpoint - sunPosition
        let destinationVector = destinationPosition - sunPosition
        let epsilon: Float = 0.000001

        guard horizontalLengthSquared(endpointVector) > epsilon,
              horizontalLengthSquared(destinationVector) > epsilon else {
            return transferOrbit.points
        }

        let radius = transferOrbit.destinationOrbitRadius
        let startDirection = normalize(endpointVector)
        let destinationDirection = normalize(destinationVector)
        let orbitAngle = connectorAngle(from: startDirection,
                                        to: destinationDirection,
                                        transferPoints: transferOrbit.points)
        let arcSampleCount = destinationArcSampleCount
        .map { max(2, $0) }
        ?? max(2, Int(ceil(abs(orbitAngle) / (2 * .pi) * 192)))
        guard arcSampleCount > 1 else { return transferOrbit.points }

        let orbitPoints = (1...arcSampleCount).map { index in
            let progress = Float(index) / Float(arcSampleCount)
            let angle = orbitAngle * progress
            return sunPosition + rotateY(startDirection * radius, angle: angle)
        }

        return transferOrbit.points + orbitPoints
    }

    // swiftlint:disable:next function_body_length
    static func makeCislunarLoopPoints(originPosition: SIMD3<Float>,
                                       waypointPosition: SIMD3<Float>,
                                       destinationPosition: SIMD3<Float>? = nil,
                                       originSurfaceRadius: Float = 0,
                                       waypointSurfaceRadius: Float = 0,
                                       destinationSurfaceRadius: Float = 0,
                                       sampleCount: Int = 192) -> [SIMD3<Float>] {
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
        let destinationClearance = ArtemisRouteProfile.anchorClearance(
            radius: destinationSurfaceRadius,
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
        let returnDirection = normalizeOrFallback(returnPosition - waypointPosition,
                                                  fallback: -majorDirection)
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
        let returnAnchor = returnPosition - returnDirection * destinationClearance
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
            startAngle: 0,
            endAngle: earthLoopEndAngle,
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
        let returnPoints = cubicBezierPoints(
            start: lunarLoopEnd,
            controlA: lunarLoopEnd
                + lunarFlybyExitTangent * lunarFlybyExitHandleScale,
            controlB: returnAnchor
                + majorDirection * outboundControlScale * 0.38
                - sideDirection * outboundControlScale * ArtemisRouteProfile.returnBranchLateralScale
                + sceneUp * outboundControlScale * 0.015,
            end: returnAnchor,
            count: returnCount
        )

        var points: [SIMD3<Float>] = []
        points.reserveCapacity(launchPoints.count + earthLoopPoints.count + outboundPoints.count
                               + lunarLoopPoints.count + returnPoints.count)
        appendSegment(launchPoints, to: &points)
        appendSegment(earthLoopPoints, to: &points)
        appendSegment(outboundPoints, to: &points)
        appendSegment(lunarLoopPoints, to: &points)
        appendSegment(returnPoints, to: &points)
        return points
    }

    static func predictedArtemisWaypointPosition(input: RouteBuildInput) -> SIMD3<Float>? {
        guard let waypointName = input.waypointName else {
            return nil
        }

        return predictedWorldPosition(
            ofPlanetNamed: waypointName,
            planets: input.planets,
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
            simulationTime: predictionSimulationTime(targetProgress: 1, input: input)
        )
    }

    static func makeCumulativeDistances(points: [SIMD3<Float>]) -> [Float] {
        guard let first = points.first else { return [] }

        var distances: [Float] = [0]
        distances.reserveCapacity(points.count)
        var previousPoint = first
        var runningDistance: Float = 0

        for point in points.dropFirst() {
            runningDistance += simd_distance(previousPoint, point)
            distances.append(runningDistance)
            previousPoint = point
        }

        return distances
    }

    private static func cislunarLoopOverviewCenter(originPosition: SIMD3<Float>,
                                                   waypointPosition: SIMD3<Float>,
                                                   destinationPosition: SIMD3<Float>) -> SIMD3<Float> {
        (originPosition + waypointPosition + destinationPosition) / 3
    }

    private static func makeCislunarMinorAxis(majorVector: SIMD3<Float>,
                                              length: Float) -> SIMD3<Float> {
        let epsilon: Float = 0.000_001
        let sceneUp = SIMD3<Float>(0, 1, 0)
        guard simd_length_squared(majorVector) > epsilon else {
            return sceneUp * length
        }

        let horizontalMajor = SIMD3<Float>(majorVector.x, 0, majorVector.z)
        if simd_length_squared(horizontalMajor) > epsilon {
            let perpendicular = normalize(SIMD3<Float>(-horizontalMajor.z, 0, horizontalMajor.x))
            return perpendicular * length
        }

        return sceneUp * length
    }

    private static func quadraticBezier(start: SIMD3<Float>,
                                        control: SIMD3<Float>,
                                        end: SIMD3<Float>,
                                        progress: Float) -> SIMD3<Float> {
        let clampedProgress = simd_clamp(progress, 0, 1)
        let inverseProgress = 1 - clampedProgress
        let startWeight = inverseProgress * inverseProgress
        let controlWeight = 2 * inverseProgress * clampedProgress
        let endWeight = clampedProgress * clampedProgress
        return startWeight * start + controlWeight * control + endWeight * end
    }

    private static func cubicBezier(start: SIMD3<Float>,
                                    controlA: SIMD3<Float>,
                                    controlB: SIMD3<Float>,
                                    end: SIMD3<Float>,
                                    progress: Float) -> SIMD3<Float> {
        let clampedProgress = simd_clamp(progress, 0, 1)
        let inverseProgress = 1 - clampedProgress
        return inverseProgress * inverseProgress * inverseProgress * start
            + 3 * inverseProgress * inverseProgress * clampedProgress * controlA
            + 3 * inverseProgress * clampedProgress * clampedProgress * controlB
            + clampedProgress * clampedProgress * clampedProgress * end
    }

    private static func quadraticBezierPoints(start: SIMD3<Float>,
                                              control: SIMD3<Float>,
                                              end: SIMD3<Float>,
                                              count: Int) -> [SIMD3<Float>] {
        sampledPoints(count: count) { progress in
            quadraticBezier(start: start,
                            control: control,
                            end: end,
                            progress: progress)
        }
    }

    private static func cubicBezierPoints(start: SIMD3<Float>,
                                          controlA: SIMD3<Float>,
                                          controlB: SIMD3<Float>,
                                          end: SIMD3<Float>,
                                          count: Int) -> [SIMD3<Float>] {
        sampledPoints(count: count) { progress in
            cubicBezier(start: start,
                        controlA: controlA,
                        controlB: controlB,
                        end: end,
                        progress: progress)
        }
    }

    private static func ellipticalArcPoints(center: SIMD3<Float>,
                                            axisA: SIMD3<Float>,
                                            axisB: SIMD3<Float>,
                                            startAngle: Float,
                                            endAngle: Float,
                                            count: Int) -> [SIMD3<Float>] {
        sampledPoints(count: count) { progress in
            let angle = startAngle + (endAngle - startAngle) * progress
            return center + axisA * cos(angle) + axisB * sin(angle)
        }
    }

    private static func sampledPoints(count: Int,
                                      point: (Float) -> SIMD3<Float>) -> [SIMD3<Float>] {
        let resolvedCount = max(count, 2)
        return (0..<resolvedCount).map { index in
            point(Float(index) / Float(resolvedCount - 1))
        }
    }

    private static func appendSegment(_ segment: [SIMD3<Float>],
                                      to points: inout [SIMD3<Float>]) {
        guard !segment.isEmpty else { return }
        if points.isEmpty {
            points.append(contentsOf: segment)
        } else {
            points.append(contentsOf: segment.dropFirst())
        }
    }

    private static func predictionSimulationTime(targetProgress: Float,
                                                 input: RouteBuildInput) -> Float {
        let remainingProgress = max(simd_clamp(targetProgress, 0, 1)
                                    - simd_clamp(input.routeProgress, 0, 1), 0)
        return input.simulationTime + Float(input.estimatedDuration) * remainingProgress
    }

    private static func predictedWorldPosition(ofPlanetNamed planetName: String,
                                               planets: [Planet],
                                               simulationTime: Float) -> SIMD3<Float>? {
        var worldPositionsByName: [String: SIMD3<Float>] = [:]
        for planet in planets {
            let parentWorldPosition = planet.parentName.flatMap {
                worldPositionsByName[$0]
            }
            let orbitTransformMatrix = planet.orbitTransformMatrix(
                at: simulationTime,
                parentWorldPosition: parentWorldPosition
            )
            let worldPosition4 = orbitTransformMatrix * SIMD4<Float>(0, 0, 0, 1)
            let worldPosition = SIMD3<Float>(worldPosition4.x,
                                             worldPosition4.y,
                                             worldPosition4.z)
            worldPositionsByName[planet.name] = worldPosition
        }

        return worldPositionsByName[planetName]
    }

    private static func normalizeOrFallback(_ vector: SIMD3<Float>,
                                            fallback: SIMD3<Float>) -> SIMD3<Float> {
        let epsilon: Float = 0.000_001
        guard simd_length_squared(vector) > epsilon else {
            return fallback
        }

        return normalize(vector)
    }

    private static func positiveAngle(from source: SIMD3<Float>,
                                      to destination: SIMD3<Float>) -> Float {
        let sourceXZ = normalize(SIMD2<Float>(source.x, source.z))
        let destinationXZ = normalize(SIMD2<Float>(destination.x, destination.z))
        let crossValue = sourceXZ.y * destinationXZ.x - sourceXZ.x * destinationXZ.y
        let dotValue = simd_clamp(simd_dot(sourceXZ, destinationXZ), -1, 1)
        let signedAngle = atan2(crossValue, dotValue)
        return signedAngle >= 0 ? signedAngle : signedAngle + 2 * .pi
    }

    private static func connectorAngle(from source: SIMD3<Float>,
                                       to destination: SIMD3<Float>,
                                       transferPoints: [SIMD3<Float>]) -> Float {
        let angle = positiveAngle(from: source, to: destination)
        guard let arrivalDirection = finalHorizontalDirection(points: transferPoints) else {
            return angle
        }

        let positiveTangent = normalize(SIMD3<Float>(source.z, 0, -source.x))
        return simd_dot(arrivalDirection, positiveTangent) >= 0 ? angle : angle - 2 * .pi
    }

    private static func finalHorizontalDirection(points: [SIMD3<Float>]) -> SIMD3<Float>? {
        let epsilon: Float = 0.000001

        guard points.count >= 2 else { return nil }
        for upperIndex in stride(from: points.count - 1, through: 1, by: -1) {
            var direction = points[upperIndex] - points[upperIndex - 1]
            direction.y = 0
            if horizontalLengthSquared(direction) > epsilon {
                return normalize(direction)
            }
        }

        return nil
    }

    private static func rotateY(_ point: SIMD3<Float>, angle: Float) -> SIMD3<Float> {
        let cosine = cos(angle)
        let sine = sin(angle)
        return SIMD3<Float>(
            point.x * cosine + point.z * sine,
            point.y,
            -point.x * sine + point.z * cosine
        )
    }

    private static func horizontalLengthSquared(_ vector: SIMD3<Float>) -> Float {
        vector.x * vector.x + vector.z * vector.z
    }
}
