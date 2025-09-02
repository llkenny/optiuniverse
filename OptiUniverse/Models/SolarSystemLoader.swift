//
//  SolarSystemLoader.swift
//  OptiUniverse
//
//  Created by max on 05.08.2025.
//

import Foundation

final class SolarSystemLoader {
    enum Constants {
        static let diameterFactor: Float = 1e-6
        static let distanceFactor: Double = 1e-6
        static let orbitSpeedMultiplier: Float = 1e-3
    }
    
    static func loadPlanets(from filename: String) -> [Planet] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let configs = try? JSONDecoder().decode([PlanetConfig].self, from: data) else {
            return []
        }
        
        return configs.map { config in
            Planet(
                name: config.name,
                radius: (config.diameterKm / 2) * Constants.diameterFactor,
                distance: config.distanceFromSunKm * Constants.distanceFactor,
                orbitSpeed: config.orbitSpeed * Constants.orbitSpeedMultiplier,
                color: SIMD3<Float>(config.color.r, config.color.g, config.color.b),
                textureName: config.textureName
            )
        }
    }
}
