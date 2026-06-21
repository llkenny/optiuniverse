import Foundation

public enum UniverseModulePreparationError: Error, LocalizedError, Sendable {
    case requiredCelestialAssetsUnavailable

    public var errorDescription: String? {
        switch self {
        case .requiredCelestialAssetsUnavailable:
            "The universe could not load its required celestial assets."
        }
    }
}
