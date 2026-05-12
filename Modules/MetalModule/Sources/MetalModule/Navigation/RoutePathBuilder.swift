//
//  RoutePathBuilder.swift
//  MetalModule
//
//  Created by Codex on 11.05.2026.
//

import Foundation
import simd

struct RouteBuildInput {
    let destinationName: String
    let planets: [Planet]
    let earthSunDirection: SIMD3<Float>
    let sunPosition: SIMD3<Float>
    let destinationPosition: SIMD3<Float>?
    let estimatedDuration: TimeInterval
}

protocol RouteBuilding {
    func makeRoute(input: RouteBuildInput) -> NavigationRoute?
}

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
                               estimatedDuration: input.estimatedDuration)
    }

    static func makeNavigationPoints(transferOrbit: HohmannTransferOrbit,
                                     destinationPosition: SIMD3<Float>?) -> [SIMD3<Float>] {
        guard let destinationPosition,
              let transferEndpoint = transferOrbit.points.last else {
            return transferOrbit.points
        }

        let sunPosition = transferOrbit.sunPosition
        let endpointVector = transferEndpoint - sunPosition
        let destinationVector = destinationPosition - sunPosition
        let epsilon: Float = 0.000001

        guard simd_length_squared(endpointVector) > epsilon,
              simd_length_squared(destinationVector) > epsilon else {
            return transferOrbit.points
        }

        let radius = transferOrbit.destinationOrbitRadius
        let startDirection = normalize(endpointVector)
        let destinationDirection = normalize(destinationVector)
        let orbitAngle = positiveAngle(from: startDirection, to: destinationDirection)
        let arcSampleCount = max(2, Int(ceil(orbitAngle / (2 * .pi) * 192)))
        guard arcSampleCount > 1 else { return transferOrbit.points }

        let orbitPoints = (1...arcSampleCount).map { index in
            let progress = Float(index) / Float(arcSampleCount)
            let angle = orbitAngle * progress
            return sunPosition + rotateZ(startDirection * radius, angle: angle)
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
        let sourceXY = normalize(SIMD2<Float>(source.x, source.y))
        let destinationXY = normalize(SIMD2<Float>(destination.x, destination.y))
        let crossValue = sourceXY.x * destinationXY.y - sourceXY.y * destinationXY.x
        let dotValue = simd_clamp(simd_dot(sourceXY, destinationXY), -1, 1)
        let signedAngle = atan2(crossValue, dotValue)
        return signedAngle >= 0 ? signedAngle : signedAngle + 2 * .pi
    }

    private static func rotateZ(_ point: SIMD3<Float>, angle: Float) -> SIMD3<Float> {
        let cosine = cos(angle)
        let sine = sin(angle)
        return SIMD3<Float>(
            point.x * cosine - point.y * sine,
            point.x * sine + point.y * cosine,
            point.z
        )
    }
}
