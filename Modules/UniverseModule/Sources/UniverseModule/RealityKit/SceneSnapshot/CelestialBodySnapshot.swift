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

    init(planetName: String,
         baseModelMatrix: float4x4,
         orbitTransformMatrix: float4x4 = matrix_identity_float4x4,
         visualRotationMatrix: float4x4 = matrix_identity_float4x4,
         normalizedScale: Float,
         framingRadius: Float,
         surfaceRadius: Float,
         worldPosition: SIMD3<Float>) {
        self.planetName = planetName
        self.baseModelMatrix = baseModelMatrix
        self.orbitTransformMatrix = orbitTransformMatrix
        self.visualRotationMatrix = visualRotationMatrix
        self.normalizedScale = normalizedScale
        self.framingRadius = framingRadius
        self.surfaceRadius = surfaceRadius
        self.worldPosition = worldPosition
    }
}
