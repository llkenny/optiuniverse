//
//  PlanetConfig.swift
//  OptiUniverse
//
//  Created by max on 05.08.2025.
//

struct PlanetConfig: Decodable {
    struct Color: Decodable {
        let r: Float
        let g: Float
        let b: Float
    }
    let name: String
    let diameterKm: Float
    let distanceFromSunKm: Double
    let orbitSpeed: Float
    let textureName: String
    let color: Color
}
