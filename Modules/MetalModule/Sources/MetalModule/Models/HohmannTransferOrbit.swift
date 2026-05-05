//
//  HohmannTransferOrbit.swift
//  MetalModule
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
    let summary: TransferOrbitSummary

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
              simd_length_squared(earthSunDirection) > 0.000001 else {
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
            points: sampledPoints.map { $0 + sunPosition },
            summary: TransferOrbitSummary(
                destinationName: destinationName,
                earthOrbitRadiusAU: 1,
                destinationOrbitRadiusAU: destinationOrbitRadius / earthOrbitRadius,
                semiMajorAxisAU: semiMajorAxis / earthOrbitRadius
            )
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
            return rotateZ(point(trueAnomaly: trueAnomaly,
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
                            radius * sin(trueAnomaly),
                            0)
    }

    private static func signedAngle(from source: SIMD3<Float>,
                                    to destination: SIMD3<Float>) -> Float {
        let sourceXY = normalize(SIMD2<Float>(source.x, source.y))
        let destinationXY = normalize(SIMD2<Float>(destination.x, destination.y))
        let crossValue = sourceXY.x * destinationXY.y - sourceXY.y * destinationXY.x
        let dotValue = simd_clamp(simd_dot(sourceXY, destinationXY), -1, 1)
        return atan2(crossValue, dotValue)
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
