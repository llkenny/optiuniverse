import Foundation

/// Explicit mission identity, independent of celestial destination names.
public enum MissionFlightPlan: String, Sendable, Equatable {
    case artemisII = "artemis-ii"
    case starshipFlight14 = "starship-flight-14"
    case crew13 = "crew-13"
    case voyager1 = "voyager-1"

    /// UTC launch instant shared with the mission replay's first historical anchor.
    public var launchDate: Date {
        SimulationTime.date(forTDBSeconds: MissionTimeline.forMission(self).departureEpoch)
    }
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
        case interplanetaryCruise = "Interplanetary cruise"
        case jupiterFlyby = "Jupiter flyby"
        case saturnFlyby = "Saturn flyby"
        case interstellarCruise = "Journey to the heliopause"
        case interstellarSpace = "Interstellar space"
    }

    /// Shared by iOS and visionOS; tied to mission time, so backgrounding cannot dismiss it.
    public var epilogueText: String? {
        guard mission == .voyager1, phase == .interstellarSpace else { return nil }
        return "Voyager 1 has left the heliosphere and continues its journey through interstellar space."
    }

    public let mission: MissionFlightPlan
    public let phase: Phase
    public let currentOrbit: Int
    public let totalOrbits: Int
    public let deployedSatelliteCount: Int
}
