//
//  Planet.swift
//  OptiUniverse
//
//  Created by max on 05.08.2025.
//

import MetalKit

struct Planet {
    let name: String
    let radius: Float
    /// Orbital radius
    let distance: Float
    /// Rotation speed multiplier/
    let orbitSpeed: Float
    let color: SIMD3<Float>
    /// Optional axial tilt
    let tilt: Float = 0
    let textureName: String
    // TODO: Remove
    var mesh: MTKMesh?
}
