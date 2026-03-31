//
//  PlanetConfig.swift
//  OptiUniverse
//
//  Created by max on 05.08.2025.
//

struct PlanetConfig: Decodable {
    let name: String
    let meshName: String
    let diameterKm: Float
    let distanceFromSunKm: Double
    let orbitSpeed: Float
}
