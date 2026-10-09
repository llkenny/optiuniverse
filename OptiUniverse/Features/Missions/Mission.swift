import Foundation
import UniverseModule

struct Mission: Equatable, Identifiable {
    let id: String
    let title: String
    let description: String
    let flightPlan: MissionFlightPlan
    let route: MissionRoute

    static let artemisII = Mission(
        id: "artemis-ii",
        title: "Artemis II",
        description: "Earth to Moon and return",
        flightPlan: .artemisII,
        route: MissionRoute(originName: "Earth",
                            waypointName: "Moon",
                            destinationName: "Earth")
    )

    static let starshipFlight14 = Mission(
        id: "starship-flight-14",
        title: "Starship Flight 14",
        description: "Illustrative flight · compressed timing",
        flightPlan: .starshipFlight14,
        route: MissionRoute(originName: "Earth", waypointName: nil, destinationName: "Earth")
    )

    static let crew13 = Mission(
        id: "crew-13",
        title: "Crew 13",
        description: "Earth to ISS · 60 s illustrative flight",
        flightPlan: .crew13,
        route: MissionRoute(originName: "Earth", waypointName: nil, destinationName: "ISS")
    )

    static let available: [Mission] = [.artemisII, .starshipFlight14, .crew13]
}

struct MissionRoute: Equatable, Identifiable {
    let originName: String
    let waypointName: String?
    let destinationName: String

    var id: String {
        "\(originName)-\(waypointName ?? "orbit")-\(destinationName)"
    }
}

struct MissionFlowState: Equatable {
    let mission: Mission

    var route: MissionRoute {
        mission.route
    }

    init(mission: Mission) {
        self.mission = mission
    }

    func handleCompletedNavigation(originName: String?,
                                   waypointName: String?,
                                   destinationName: String?,
                                   missionID: MissionFlightPlan? = nil) -> MissionFlowAdvance {
        // Legacy Artemis callers may still complete by route; other missions require identity.
        if let missionID {
            guard missionID == mission.flightPlan else { return .noChange }
        } else if mission.flightPlan != .artemisII {
            return .noChange
        }
        guard route.originName == originName,
              route.waypointName == waypointName,
              route.destinationName == destinationName else {
            return .noChange
        }

        return .complete
    }
}

enum MissionFlowAdvance: Equatable {
    case complete
    case noChange
}
