//
//  HohmannTransferOrbit.swift
//  UniverseModule
//
//  Created by Codex on 05.05.2026.
//

import simd

struct HohmannTransferOrbit: Equatable, Sendable {
    let destinationName: String
    let earthOrbitRadius: Float
    let destinationOrbitRadius: Float
    let semiMajorAxis: Float
    let sunPosition: SIMD3<Float>
    let points: [SIMD3<Float>]

    static func make(destinationName: String,
                     planets: [Planet],
                     earthSunDirection: SIMD3<Float>,
                     sunPosition: SIMD3<Float> = .zero,
                     sampleCount: Int = 192) -> HohmannTransferOrbit? {
        guard sampleCount >= 2,
              let earth = planets.first(where: { $0.name == "Earth" }),
              let destination = planets.first(where: { $0.name == destinationName }),
              isSupportedDestination(destination),
              earth.distance > 0,
              destination.distance > 0,
              horizontalLengthSquared(earthSunDirection) > 0.000001 else {
            return nil
        }

        let earthOrbitRadius = earth.distance
        let destinationOrbitRadius = destination.distance
        let semiMajorAxis = (earthOrbitRadius + destinationOrbitRadius) / 2
        let sampledPoints = makeArcPoints(earthOrbitRadius: earthOrbitRadius,
                                          destinationOrbitRadius: destinationOrbitRadius,
                                          earthSunDirection: earthSunDirection,
                                          sampleCount: sampleCount)

        return HohmannTransferOrbit(
            destinationName: destinationName,
            earthOrbitRadius: earthOrbitRadius,
            destinationOrbitRadius: destinationOrbitRadius,
            semiMajorAxis: semiMajorAxis,
            sunPosition: sunPosition,
            points: sampledPoints.map { $0 + sunPosition }
        )
    }

    private static func isSupportedDestination(_ planet: Planet) -> Bool {
        planet.name != "Sun" &&
        planet.name != "Earth" &&
        planet.parentName == nil
    }

    private static func makeArcPoints(earthOrbitRadius: Float,
                                      destinationOrbitRadius: Float,
                                      earthSunDirection: SIMD3<Float>,
                                      sampleCount: Int) -> [SIMD3<Float>] {
        let innerRadius = min(earthOrbitRadius, destinationOrbitRadius)
        let outerRadius = max(earthOrbitRadius, destinationOrbitRadius)
        let eccentricity = (outerRadius - innerRadius) / (outerRadius + innerRadius)
        let semiLatusRectum = 2 * innerRadius * outerRadius / (innerRadius + outerRadius)
        let isOutwardTransfer = destinationOrbitRadius >= earthOrbitRadius
        let departureTrueAnomaly: Float = isOutwardTransfer ? 0 : .pi
        let destinationTrueAnomaly: Float = isOutwardTransfer ? .pi : 0
        let departureReferencePoint = point(trueAnomaly: departureTrueAnomaly,
                                            eccentricity: eccentricity,
                                            semiLatusRectum: semiLatusRectum)
        let rotationAngle = signedAngle(from: departureReferencePoint,
                                        to: earthSunDirection)

        return (0..<sampleCount).map { index in
            let progress = Float(index) / Float(sampleCount - 1)
            let trueAnomaly = departureTrueAnomaly +
            (destinationTrueAnomaly - departureTrueAnomaly) * progress
            return rotateY(point(trueAnomaly: trueAnomaly,
                                 eccentricity: eccentricity,
                                 semiLatusRectum: semiLatusRectum),
                           angle: rotationAngle)
        }
    }

    private static func point(trueAnomaly: Float,
                              eccentricity: Float,
                              semiLatusRectum: Float) -> SIMD3<Float> {
        let radius = semiLatusRectum / (1 + eccentricity * cos(trueAnomaly))
        return SIMD3<Float>(radius * cos(trueAnomaly),
                            0,
                            -radius * sin(trueAnomaly))
    }

    private static func signedAngle(from source: SIMD3<Float>,
                                    to destination: SIMD3<Float>) -> Float {
        let sourceXZ = normalize(SIMD2<Float>(source.x, source.z))
        let destinationXZ = normalize(SIMD2<Float>(destination.x, destination.z))
        let crossValue = sourceXZ.y * destinationXZ.x - sourceXZ.x * destinationXZ.y
        let dotValue = simd_clamp(simd_dot(sourceXZ, destinationXZ), -1, 1)
        return atan2(crossValue, dotValue)
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
