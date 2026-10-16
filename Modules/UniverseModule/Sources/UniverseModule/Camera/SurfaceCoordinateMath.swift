//
//  SurfaceCoordinateMath.swift
//  UniverseModule
//
//  Created by Codex on 06.06.2026.
//

import Foundation
import simd

struct SurfaceCoordinate: Equatable, Sendable {
    let latitudeDegrees: Float
    let longitudeDegrees: Float
}

struct SurfaceRaySphereHit: Equatable, Sendable {
    let worldPoint: SIMD3<Float>
    let distance: Float
    let isTangent: Bool
}

enum SurfaceCoordinateMath {
    private static let epsilon: Float = 0.000001

    static func localUnitVector(for coordinate: SurfaceCoordinate) -> SIMD3<Float> {
        let latitude = coordinate.latitudeDegrees * .pi / 180
        let longitude = coordinate.longitudeDegrees * .pi / 180
        let equatorRadius = cos(latitude)
        let vector = SIMD3<Float>(
            equatorRadius * cos(longitude),
            sin(latitude),
            -equatorRadius * sin(longitude)
        )

        guard simd_length_squared(vector) > epsilon * epsilon else {
            return SIMD3<Float>(1, 0, 0)
        }
        return simd_normalize(vector)
    }

    static func coordinate(fromLocalUnitVector vector: SIMD3<Float>) -> SurfaceCoordinate? {
        guard simd_length_squared(vector) > epsilon * epsilon else {
            return nil
        }

        let unitVector = simd_normalize(vector)
        let clampedY = min(max(unitVector.y, -1), 1)
        let latitude = asin(clampedY) * 180 / .pi
        let longitude = atan2(-unitVector.z, unitVector.x) * 180 / .pi
        return SurfaceCoordinate(latitudeDegrees: latitude,
                                 longitudeDegrees: normalizedLongitude(longitude))
    }

    static func worldSurfacePoint(on planet: CelestialBodySnapshot,
                                  at coordinate: SurfaceCoordinate) -> SIMD3<Float> {
        SIMD3<Float>(preciseWorldSurfacePoint(on: planet, at: coordinate))
    }

    static func preciseWorldSurfacePoint(on planet: CelestialBodySnapshot,
                                         at coordinate: SurfaceCoordinate) -> SIMD3<Double> {
        planet.preciseWorldPosition + SIMD3<Double>(surfaceOffset(on: planet, at: coordinate))
    }

    static func surfaceOffset(on planet: CelestialBodySnapshot,
                              at coordinate: SurfaceCoordinate) -> SIMD3<Float> {
        let localPoint = localUnitVector(for: coordinate) * planet.surfaceRadius
        let point = planet.visualRotationMatrix * SIMD4<Float>(localPoint, 0)
        return SIMD3(point.x, point.y, point.z)
    }

    static func coordinate(on planet: CelestialBodySnapshot,
                           forWorldPoint worldPoint: SIMD3<Float>) -> SurfaceCoordinate? {
        coordinate(on: planet, forPreciseWorldPoint: SIMD3<Double>(worldPoint))
    }

    static func coordinate(on planet: CelestialBodySnapshot,
                           forPreciseWorldPoint worldPoint: SIMD3<Double>) -> SurfaceCoordinate? {
        let offset = SIMD3<Float>(worldPoint - planet.preciseWorldPosition)
        let localPoint = simd_inverse(planet.visualRotationMatrix) * SIMD4<Float>(offset, 0)
        return coordinate(fromLocalUnitVector: SIMD3<Float>(localPoint.x,
                                                            localPoint.y,
                                                            localPoint.z))
    }

    static func referenceSphereIntersection(rayOrigin: SIMD3<Float>,
                                            rayDirection: SIMD3<Float>,
                                            planet: CelestialBodySnapshot)
    -> SurfaceRaySphereHit? {
        guard planet.surfaceRadius > epsilon else { return nil }
        guard simd_length_squared(rayDirection) > epsilon * epsilon else { return nil }

        let direction = simd_normalize(rayDirection)
        let offset = rayOrigin - planet.worldPosition
        let linearTerm = 2 * simd_dot(offset, direction)
        let constantTerm = simd_dot(offset, offset) - planet.surfaceRadius * planet.surfaceRadius
        let discriminant = linearTerm * linearTerm - 4 * constantTerm

        guard discriminant >= -epsilon else {
            return nil
        }

        let isTangent = abs(discriminant) <= epsilon
        let squareRoot = sqrt(max(discriminant, 0))
        let nearDistance = (-linearTerm - squareRoot) * 0.5
        let farDistance = (-linearTerm + squareRoot) * 0.5
        let distance: Float
        if nearDistance >= 0 {
            distance = nearDistance
        } else if farDistance >= 0 {
            distance = farDistance
        } else {
            return nil
        }

        return SurfaceRaySphereHit(worldPoint: rayOrigin + direction * distance,
                                   distance: distance,
                                   isTangent: isTangent)
    }

    static func centerRayIntersection(cameraWorldPosition: SIMD3<Float>,
                                      cameraTarget: SIMD3<Float>,
                                      planet: CelestialBodySnapshot)
    -> SurfaceRaySphereHit? {
        referenceSphereIntersection(
            rayOrigin: cameraWorldPosition,
            rayDirection: cameraTarget - cameraWorldPosition,
            planet: planet
        )
    }

    /// Solve in a body-relative frame before adding the heliocentric translation.
    static func preciseCenterRayIntersection(cameraWorldPosition: SIMD3<Double>,
                                              cameraTarget: SIMD3<Double>,
                                              planet: CelestialBodySnapshot) -> SIMD3<Double>? {
        let directionInput = cameraTarget - cameraWorldPosition
        guard simd_length_squared(directionInput) > 1e-24, planet.surfaceRadius > 0 else { return nil }
        let direction = simd_normalize(directionInput)
        let offset = cameraWorldPosition - planet.preciseWorldPosition
        let projection = simd_dot(offset, direction)
        let radius = Double(planet.surfaceRadius)
        let discriminant = projection * projection - simd_length_squared(offset) + radius * radius
        guard discriminant >= 0 else { return nil }
        let near = -projection - sqrt(discriminant)
        let far = -projection + sqrt(discriminant)
        let distance = near >= 0 ? near : far
        guard distance >= 0 else { return nil }
        return planet.preciseWorldPosition + (offset + direction * distance)
    }

    private static func normalizedLongitude(_ longitude: Float) -> Float {
        var normalized = longitude.truncatingRemainder(dividingBy: 360)
        if normalized >= 180 {
            normalized -= 360
        } else if normalized < -180 {
            normalized += 360
        }
        return normalized
    }
}
