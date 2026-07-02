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
    let destinationName: String
    let planets: [Planet]
    let earthSunDirection: SIMD3<Float>
    let sunPosition: SIMD3<Float>
    let destinationPosition: SIMD3<Float>?
    let estimatedDuration: TimeInterval
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
        let orbitAngle = positiveAngle(from: startDirection, to: destinationDirection)
        let arcSampleCount = destinationArcSampleCount
        .map { max(2, $0) }
        ?? max(2, Int(ceil(orbitAngle / (2 * .pi) * 192)))
        guard arcSampleCount > 1 else { return transferOrbit.points }

        let orbitPoints = (1...arcSampleCount).map { index in
            let progress = Float(index) / Float(arcSampleCount)
            let angle = orbitAngle * progress
            return sunPosition + rotateY(startDirection * radius, angle: angle)
        }

        return transferOrbit.points + orbitPoints
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

    private static func positiveAngle(from source: SIMD3<Float>,
                                      to destination: SIMD3<Float>) -> Float {
        let sourceXZ = normalize(SIMD2<Float>(source.x, source.z))
        let destinationXZ = normalize(SIMD2<Float>(destination.x, destination.z))
        let crossValue = sourceXZ.y * destinationXZ.x - sourceXZ.x * destinationXZ.y
        let dotValue = simd_clamp(simd_dot(sourceXZ, destinationXZ), -1, 1)
        let signedAngle = atan2(crossValue, dotValue)
        return signedAngle >= 0 ? signedAngle : signedAngle + 2 * .pi
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
