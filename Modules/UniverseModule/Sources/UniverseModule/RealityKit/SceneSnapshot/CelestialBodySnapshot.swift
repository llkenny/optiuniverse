//
//  CelestialBodySnapshot.swift
//  UniverseModule
//
//  Created by max on 24.05.2026.
//

import simd

struct CelestialBodySnapshot: Sendable {
    let planetName: String
    let baseModelMatrix: float4x4
    let orbitTransformMatrix: float4x4
    let visualRotationMatrix: float4x4
    let normalizedScale: Float
    let framingRadius: Float
    let surfaceRadius: Float
    let worldPosition: SIMD3<Float>
    let preciseWorldPosition: SIMD3<Double>

    init(planetName: String,
         baseModelMatrix: float4x4,
         orbitTransformMatrix: float4x4 = matrix_identity_float4x4,
         visualRotationMatrix: float4x4? = nil,
         normalizedScale: Float,
         framingRadius: Float,
         surfaceRadius: Float,
         worldPosition: SIMD3<Float>,
         preciseWorldPosition: SIMD3<Double>? = nil) {
        self.planetName = planetName
        self.baseModelMatrix = baseModelMatrix
        self.orbitTransformMatrix = orbitTransformMatrix
        self.visualRotationMatrix = visualRotationMatrix ?? float4x4(
            SIMD4(baseModelMatrix.columns.0.x, baseModelMatrix.columns.0.y, baseModelMatrix.columns.0.z, 0),
            SIMD4(baseModelMatrix.columns.1.x, baseModelMatrix.columns.1.y, baseModelMatrix.columns.1.z, 0),
            SIMD4(baseModelMatrix.columns.2.x, baseModelMatrix.columns.2.y, baseModelMatrix.columns.2.z, 0), SIMD4(0, 0, 0, 1))
        self.normalizedScale = normalizedScale
        self.framingRadius = framingRadius
        self.surfaceRadius = surfaceRadius
        self.worldPosition = worldPosition
        self.preciseWorldPosition = preciseWorldPosition ?? SIMD3<Double>(worldPosition)
    }
}
