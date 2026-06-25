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
    let normalizedScale: Float
    let framingRadius: Float
    let surfaceRadius: Float
    let worldPosition: SIMD3<Float>
}
