import Foundation

/// Explicit mission identity, independent of celestial destination names.
public enum MissionFlightPlan: String, Sendable, Equatable {
    case artemisII = "artemis-ii"
    case starshipFlight14 = "starship-flight-14"
    case crew13 = "crew-13"
}

public struct MissionNavigationStatus: Sendable, Equatable {
    public enum Phase: String, Sendable {
        case launch = "Launch"
        case separation = "Stage separation"
        case secondStageBurn = "Second-stage burn"
        case dragonSeparation = "Dragon separation"
        case rendezvous = "ISS rendezvous"
        case docking = "Docking"
        case docked = "Docked at ISS"
        case boosterReturn = "Super Heavy splashdown"
        case orbit = "Orbit"
        case deployment = "Deploying Starlinks"
        case deorbit = "Deorbit burn"
        case reentry = "Reentry"
        case landing = "Landing burn"
        case splashdown = "Splashdown"
    }

    public let mission: MissionFlightPlan
    public let phase: Phase
    public let currentOrbit: Int
    public let totalOrbits: Int
    public let deployedSatelliteCount: Int
}
