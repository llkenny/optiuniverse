import Foundation

public enum UniverseModulePreparationError: Error, LocalizedError, Sendable {
    case invalidOrbitalData
    case requiredCelestialAssetsUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidOrbitalData:
            "The universe could not load its orbital data."
        case .requiredCelestialAssetsUnavailable:
            "The universe could not load its required celestial assets."
        }
    }
}
