//
//  PlanetConfig.swift
//  OptiUniverse
//
//  Created by max on 05.08.2025.
//

struct PlanetConfig: Decodable {
    // TODO: Clean fields (like Planet struct)
    struct Color: Decodable {
        let r: Float
        let g: Float
        let b: Float
    }
    let name: String
    let meshName: String
    let diameterKm: Float
    let distanceFromSunKm: Double
    let orbitSpeed: Float
    let color: Color
}
