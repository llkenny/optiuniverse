import BaseModule
import Foundation

struct MissionLaunchPlan {
    let flowState: MissionFlowState
    let selectedDestinationID: UUID?
    let selectedPlanet: String?
    let screen: AppEnvironment.Screen
    let objectsViewState: ObjectsViewState

    var route: MissionRoute {
        flowState.route
    }

    init(mission: Mission) {
        flowState = MissionFlowState(mission: mission)
        selectedDestinationID = nil
        selectedPlanet = nil
        screen = .objects
        objectsViewState = .navigation
    }
}
