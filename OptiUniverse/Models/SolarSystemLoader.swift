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
        static let distanceFactor: Float = 1e-6
        static let orbitSpeedMultiplier: Float = 1e-3
        static let rotationSpeedKmSecMultiplier: Float = 1e-3
    }
    
    static func loadPlanetConfigs(from filename: String) -> [PlanetConfig] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let configs = try? JSONDecoder().decode([PlanetConfig].self, from: data) else {
            return []
        }
        return configs
    }

    static func loadPlanets(from filename: String) -> [Planet] {
        let configs = loadPlanetConfigs(from: filename)
        
        return configs.map { config in
            Planet(
                name: config.name,
                meshName: config.meshName,
                radius: (config.diameterKm / 2) * Constants.diameterFactor,
                distance: Float(config.distanceFromSunKm) * Constants.distanceFactor,
                orbitSpeed: config.orbitSpeed * Constants.orbitSpeedMultiplier,
                rotationSpeedKmSec: config.rotationSpeedKmSec * Constants.rotationSpeedKmSecMultiplier
            )
        }
    }
}
