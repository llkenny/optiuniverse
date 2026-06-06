//
//  PreparedPlanetRenderPacket.swift
//  MetalModule
//
//  Created by max on 24.05.2026.
//

import simd

struct PreparedPlanetRenderPacket: Sendable {
    let planetName: String
    let meshes: [LoadedMesh]
    let baseModelMatrix: float4x4
    let worldModelMatrix: float4x4
    let normalizedScale: Float
    let primaryMeshRadius: Float
    let framingRadius: Float
    let surfaceRadius: Float
    let worldPosition: SIMD3<Float>
}
