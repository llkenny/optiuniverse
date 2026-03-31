//
//  Planet.swift
//  OptiUniverse
//
//  Created by max on 05.08.2025.
//

import MetalKit

struct Planet {
    let name: String
    let meshName: String
    let radius: Float
    /// Orbital radius
    let distance: Float
    /// Rotation speed multiplier/
    let orbitSpeed: Float
    // TODO: Remove?
    let color: SIMD3<Float>
    /// Optional axial tilt
    let tilt: Float = 0
}
