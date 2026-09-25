import Foundation

final class SolarSystemLoader {
    enum Constants {
        static let diameterFactor: Float = 1e-6
        static let rotationSpeedKmSecMultiplier: Float = 1e-3
    }

    static func loadPlanets(from filename: String) throws -> [Planet] {
        guard let url = Bundle.module.url(forResource: filename, withExtension: "json") else {
            throw UniverseModulePreparationError.invalidOrbitalData
        }
        return try decodePlanets(from: Data(contentsOf: url))
    }

    static func decodePlanets(from data: Data) throws -> [Planet] {
        let configs = try JSONDecoder().decode([PlanetConfig].self, from: data)
        var precedingNames = Set<String>()
        return try configs.map { config in
            guard !config.name.isEmpty, !precedingNames.contains(config.name),
                  config.diameterKm.isFinite, config.diameterKm > 0,
                  config.rotationSpeedKmSec.isFinite,
                  config.parentName.map({ precedingNames.contains($0) }) ?? true,
                  config.name == "Sun" ? config.orbit == nil : config.orbit?.isValid == true else {
                throw UniverseModulePreparationError.invalidOrbitalData
            }
            precedingNames.insert(config.name)
            return Planet(name: config.name, meshName: config.meshName,
                          parentName: config.parentName,
                          radius: config.diameterKm / 2 * Constants.diameterFactor,
                          orbit: config.orbit,
                          rotationSpeedKmSec: config.rotationSpeedKmSec * Constants.rotationSpeedKmSecMultiplier)
        }
    }
}
