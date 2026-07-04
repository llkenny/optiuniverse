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
         estimatedDuration: TimeInterval) {
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
                                waypointPosition: waypointPosition
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

    static func makeCislunarLoopPoints(originPosition: SIMD3<Float>,
                                       waypointPosition: SIMD3<Float>,
                                       originSurfaceRadius: Float = 0,
                                       waypointSurfaceRadius: Float = 0,
                                       destinationSurfaceRadius: Float = 0,
                                       sampleCount: Int = 192) -> [SIMD3<Float>] {
        let minimumCount = max(sampleCount, 3)
        let count = minimumCount.isMultiple(of: 2) ? minimumCount + 1 : minimumCount
        let majorVector = (waypointPosition - originPosition) * 0.5
        let fullMajorVector = waypointPosition - originPosition
        let fullMajorDistance = simd_length(fullMajorVector)
        let majorDirection = fullMajorDistance > 0.000_001
            ? fullMajorVector / fullMajorDistance
            : SIMD3<Float>(1, 0, 0)
        let center = originPosition + majorVector
        let majorDistance = simd_length(majorVector)
        let minorDistance = max(majorDistance * 0.55, 0.03)
        let minorVector = makeCislunarMinorAxis(majorVector: majorVector,
                                                length: minorDistance)
        let originClearance = ArtemisRouteProfile.anchorClearance(
            radius: originSurfaceRadius,
            maximumDistance: fullMajorDistance
        )
        let waypointClearance = ArtemisRouteProfile.anchorClearance(
            radius: waypointSurfaceRadius,
            maximumDistance: fullMajorDistance
        )
        let destinationClearance = ArtemisRouteProfile.anchorClearance(
            radius: destinationSurfaceRadius,
            maximumDistance: fullMajorDistance
        )
        let launchAnchor = originPosition + majorDirection * originClearance
        let moonFlybyAnchor = waypointPosition - majorDirection * waypointClearance
        let returnAnchor = originPosition - majorDirection * destinationClearance
        let outboundControl = center + minorVector
        let returnControl = center - minorVector
        let halfIndex = count / 2

        return (0..<count).map { index in
            if index <= halfIndex {
                let progress = Float(index) / Float(max(halfIndex, 1))
                return quadraticBezier(start: launchAnchor,
                                       control: outboundControl,
                                       end: moonFlybyAnchor,
                                       progress: progress)
            }

            let progress = Float(index - halfIndex) / Float(max(count - 1 - halfIndex, 1))
            return quadraticBezier(start: moonFlybyAnchor,
                                   control: returnControl,
                                   end: returnAnchor,
                                   progress: progress)
        }
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
                                                   waypointPosition: SIMD3<Float>) -> SIMD3<Float> {
        originPosition + (waypointPosition - originPosition) * 0.5
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
