import Testing
@testable import OptiUniverse

@MainActor
@Test func artemisIIMissionDefinesEarthMoonReturn() throws {
    let mission = Mission.artemisII

    #expect(mission.title == "Artemis II")
    #expect(mission.description == "Earth to Moon and return")
    #expect(mission.route == MissionRoute(originName: "Earth",
                                          waypointName: "Moon",
                                          destinationName: "Earth"))
}

@MainActor
@Test func missionFlowCompletesAfterContinuousRoute() throws {
    let state = MissionFlowState(mission: .artemisII)

    let advance = state.handleCompletedNavigation(originName: "Earth",
                                                  waypointName: "Moon",
                                                  destinationName: "Earth")

    #expect(advance == .complete)
}

@MainActor
@Test func missionFlowIgnoresUnmatchedNavigationCompletion() throws {
    let state = MissionFlowState(mission: .artemisII)

    let advance = state.handleCompletedNavigation(originName: "Earth",
                                                  waypointName: "Moon",
                                                  destinationName: "Mars")

    #expect(advance == .noChange)
    #expect(state.route == MissionRoute(originName: "Earth",
                                        waypointName: "Moon",
                                        destinationName: "Earth"))
}

@MainActor
@Test func missionLaunchPlanClearsNormalSelectionBeforeNavigation() throws {
    let plan = MissionLaunchPlan(mission: .artemisII)

    #expect(plan.selectedDestinationID == nil)
    #expect(plan.selectedPlanet == nil)
    #expect(isObjectsScreen(plan.screen))
    #expect(plan.objectsViewState == .navigation)
    #expect(plan.route == MissionRoute(originName: "Earth",
                                       waypointName: "Moon",
                                       destinationName: "Earth"))
}

@MainActor
@Test func starshipCatalogAndLaunchPlanUseExplicitMission() {
    let mission = Mission.starshipFlight14
    #expect(Mission.available == [.artemisII, .starshipFlight14, .crew13])
    #expect(mission.id == "starship-flight-14")
    #expect(mission.flightPlan == .starshipFlight14)
    #expect(mission.description == "Illustrative flight · compressed timing")
    let plan = MissionLaunchPlan(mission: mission)
    #expect(plan.flowState.mission == mission)
    #expect(plan.selectedPlanet == nil)
    #expect(plan.objectsViewState == .navigation)
}

@MainActor
@Test func starshipCompletionRequiresMatchingMissionIdentity() {
    let state = MissionFlowState(mission: .starshipFlight14)
    #expect(state.handleCompletedNavigation(originName: "Earth", waypointName: nil,
                                            destinationName: "Earth") == .noChange)
    #expect(state.handleCompletedNavigation(originName: "Earth", waypointName: nil,
                                            destinationName: "Earth", missionID: .artemisII) == .noChange)
    #expect(state.handleCompletedNavigation(originName: "Earth", waypointName: nil,
                                            destinationName: "Earth", missionID: .starshipFlight14) == .complete)
}

@MainActor
@Test func crew13CatalogAndLaunchPlanUseISSRoute() {
    let mission = Mission.crew13
    #expect(Mission.available.last == mission)
    #expect(mission.id == "crew-13")
    #expect(mission.title == "Crew 13")
    #expect(mission.description == "Earth to ISS · 60 s illustrative flight")
    #expect(mission.flightPlan == .crew13)
    let plan = MissionLaunchPlan(mission: mission)
    #expect(plan.flowState.mission == mission)
    #expect(plan.selectedDestinationID == nil)
    #expect(plan.selectedPlanet == nil)
    #expect(isObjectsScreen(plan.screen))
    #expect(plan.objectsViewState == .navigation)
    #expect(plan.route == MissionRoute(originName: "Earth", waypointName: nil, destinationName: "ISS"))
}

@MainActor
@Test func crew13CompletionRequiresItsIdentityAndISSArrival() {
    let state = MissionFlowState(mission: .crew13)
    #expect(state.handleCompletedNavigation(originName: "Earth", waypointName: nil,
                                            destinationName: "ISS") == .noChange)
    #expect(state.handleCompletedNavigation(originName: "Earth", waypointName: nil,
                                            destinationName: "ISS", missionID: .starshipFlight14) == .noChange)
    #expect(state.handleCompletedNavigation(originName: "Earth", waypointName: nil,
                                            destinationName: "Earth", missionID: .crew13) == .noChange)
    #expect(state.handleCompletedNavigation(originName: "Earth", waypointName: nil,
                                            destinationName: "ISS", missionID: .crew13) == .complete)
}
