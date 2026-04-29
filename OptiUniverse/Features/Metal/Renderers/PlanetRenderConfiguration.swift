//
//  PlanetRenderConfiguration.swift
//  OptiUniverse
//
//  Created by max on 29.04.2026.
//

import Metal
import simd

struct PlanetRenderConfiguration {
    let snapshot: PreparedRenderSnapshot?
    let renderEncoder: MTLRenderCommandEncoder
    let viewMatrix: float4x4
    let projectionMatrix: float4x4
    let cameraPosition: SIMD3<Float>
    let sceneOrigin: SIMD3<Float>
    let viewportSize: CGSize
}
