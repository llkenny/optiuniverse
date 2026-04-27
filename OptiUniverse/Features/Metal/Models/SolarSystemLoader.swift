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

    static func loadPlanets(from filename: String) -> [Planet] {
        let configs: [PlanetConfig] = Bundle.main.loadConfig(filename: filename)
        
        return configs.map { config in
            let orbitalDistanceKm = config.distanceFromParentKm ?? config.distanceFromSunKm
            return Planet(
                name: config.name,
                meshName: config.meshName,
                parentName: config.parentName,
                radius: (config.diameterKm / 2) * Constants.diameterFactor,
                distance: Float(orbitalDistanceKm) * Constants.distanceFactor,
                orbitSpeed: config.orbitSpeed * Constants.orbitSpeedMultiplier,
                rotationSpeedKmSec: config.rotationSpeedKmSec * Constants.rotationSpeedKmSecMultiplier
            )
        }
    }
}
