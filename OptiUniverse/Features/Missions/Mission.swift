import Foundation
import UniverseModule

struct Mission: Equatable, Identifiable {
    let id: String
    let title: String
    let goals: String
    let description: String
    let flightPlan: MissionFlightPlan
    let route: MissionRoute

    var launchDate: Date { flightPlan.launchDate }

    static let artemisII = Mission(
        id: "artemis-ii",
        title: "Artemis II",
        goals: "Fly around the Moon and return",
        description: "Follow a crewed lunar flyby from Earth to the Moon and back through atmospheric entry.",
        flightPlan: .artemisII,
        route: MissionRoute(originName: "Earth",
                            waypointName: "Moon",
                            destinationName: "Earth")
    )

    static let starshipFlight14 = Mission(
        id: "starship-flight-14",
        title: "Starship Flight 14",
        goals: "Test Starship and deploy Starlinks",
        description: "Follow launch, satellite deployment, reentry and ocean splashdown "
            + "in a compressed illustrative flight.",
        flightPlan: .starshipFlight14,
        route: MissionRoute(originName: "Earth", waypointName: nil, destinationName: "Earth")
    )

    static let crew13 = Mission(
        id: "crew-13",
        title: "Crew 13",
        goals: "Deliver crew to the ISS",
        description: "Follow Falcon 9 and Crew Dragon from launch to docking with the International Space Station.",
        flightPlan: .crew13,
        route: MissionRoute(originName: "Earth", waypointName: nil, destinationName: "ISS")
    )

    static let voyager1 = Mission(
        id: "voyager-1", title: "Voyager 1",
        goals: "Explore Jupiter, Saturn and interstellar space",
        description: "Follow Titan IIIE/Centaur launch, giant-planet flybys and the journey beyond the heliosphere "
            + "in a 90-second illustrative flight.",
        flightPlan: .voyager1,
        route: MissionRoute(originName: "Earth", waypointName: nil, destinationName: "Interstellar space")
    )

    static let available = sortedByLaunchDate([.artemisII, .starshipFlight14, .crew13, .voyager1])

    static func sortedByLaunchDate(_ missions: [Mission]) -> [Mission] {
        missions.sorted {
            $0.launchDate == $1.launchDate ? $0.id < $1.id : $0.launchDate > $1.launchDate
        }
    }
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
