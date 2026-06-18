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
            equatorRadius * sin(longitude),
            sin(latitude)
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
        let clampedZ = min(max(unitVector.z, -1), 1)
        let latitude = asin(clampedZ) * 180 / .pi
        let longitude = atan2(unitVector.y, unitVector.x) * 180 / .pi
        return SurfaceCoordinate(latitudeDegrees: latitude,
                                 longitudeDegrees: normalizedLongitude(longitude))
    }

    static func worldSurfacePoint(on planet: PreparedPlanetRenderPacket,
                                  at coordinate: SurfaceCoordinate) -> SIMD3<Float> {
        let localPoint = localUnitVector(for: coordinate) * planet.surfaceRadius
        let worldPoint = planet.baseModelMatrix * SIMD4<Float>(localPoint, 1)
        return SIMD3<Float>(worldPoint.x, worldPoint.y, worldPoint.z)
    }

    static func coordinate(on planet: PreparedPlanetRenderPacket,
                           forWorldPoint worldPoint: SIMD3<Float>) -> SurfaceCoordinate? {
        let localPoint = simd_inverse(planet.baseModelMatrix) * SIMD4<Float>(worldPoint, 1)
        return coordinate(fromLocalUnitVector: SIMD3<Float>(localPoint.x,
                                                            localPoint.y,
                                                            localPoint.z))
    }

    static func referenceSphereIntersection(rayOrigin: SIMD3<Float>,
                                            rayDirection: SIMD3<Float>,
                                            planet: PreparedPlanetRenderPacket)
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
                                      planet: PreparedPlanetRenderPacket)
    -> SurfaceRaySphereHit? {
        referenceSphereIntersection(
            rayOrigin: cameraWorldPosition,
            rayDirection: cameraTarget - cameraWorldPosition,
            planet: planet
        )
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
