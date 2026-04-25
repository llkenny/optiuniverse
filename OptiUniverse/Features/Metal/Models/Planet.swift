//
//  Planet.swift
//  OptiUniverse
//
//  Created by max on 05.08.2025.
//

import MetalKit

struct Planet: Sendable {
    let name: String
    let meshName: String
    let radius: Float
    /// Orbital radius
    let distance: Float
    /// Rotation speed multiplier/
    let orbitSpeed: Float
    /// Optional axial tilt
    let tilt: Float = 0
    let rotationSpeedKmSec: Float
}
