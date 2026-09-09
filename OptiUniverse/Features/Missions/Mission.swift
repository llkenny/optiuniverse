import Foundation

struct Mission: Equatable, Identifiable {
    let id: String
    let title: String
    let description: String
    let route: MissionRoute

    static let artemisII = Mission(
        id: "artemis-ii",
        title: "Artemis II",
        description: "Earth to Moon and return",
        route: MissionRoute(originName: "Earth",
                            waypointName: "Moon",
                            destinationName: "Earth")
    )

    static let available: [Mission] = [.artemisII]
}

struct MissionRoute: Equatable, Identifiable {
    let originName: String
    let waypointName: String
    let destinationName: String

    var id: String {
        "\(originName)-\(waypointName)-\(destinationName)"
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
                                   destinationName: String?) -> MissionFlowAdvance {
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
