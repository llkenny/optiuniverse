import Foundation
import Testing
@testable import OptiUniverse

@MainActor
@Test func artemisIIMissionDefinesEarthMoonReturn() throws {
    let mission = Mission.artemisII

    #expect(mission.title == "Artemis II")
    #expect(mission.goals == "Fly around the Moon and return")
    #expect(mission.description == "Follow a crewed lunar flyby from Earth to the Moon "
            + "and back through atmospheric entry.")
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
    #expect(Mission.available == [.crew13, .starshipFlight14, .artemisII, .voyager1])
    #expect(mission.id == "starship-flight-14")
    #expect(mission.flightPlan == .starshipFlight14)
    #expect(mission.goals == "Test Starship and deploy Starlinks")
    #expect(!mission.description.isEmpty)
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
    #expect(Mission.available.first == mission)
    #expect(mission.id == "crew-13")
    #expect(mission.title == "Crew 13")
    #expect(mission.goals == "Deliver crew to the ISS")
    #expect(!mission.description.isEmpty)
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

@MainActor
@Test func missionCatalogSortsEqualLaunchDatesByID() {
    let earlierID = Mission(id: "a", title: "First", goals: "Test", description: "Test mission.",
                            flightPlan: .crew13, route: Mission.crew13.route)
    let laterID = Mission(id: "z", title: "Last", goals: "Test", description: "Test mission.",
                          flightPlan: .crew13, route: Mission.crew13.route)
    #expect(Mission.sortedByLaunchDate([laterID, .artemisII, earlierID]) == [earlierID, laterID, .artemisII])
}

@MainActor
@Test func voyagerCatalogAndCompletionUseMissionIdentityWithoutACelestialDestination() {
    let mission = Mission.voyager1
    #expect(Mission.available.last == mission)
    #expect(mission.id == "voyager-1")
    #expect(mission.flightPlan == .voyager1)
    #expect(MissionCardModel(mission: mission).imageResource == .dstSaturn)
    let card = MissionCardModel(mission: mission)
    #expect(card.formattedLaunchDate(locale: Locale(identifier: "en_US")) == "Sep 5, 1977")
    let plan = MissionLaunchPlan(mission: mission)
    #expect(plan.selectedDestinationID == nil)
    #expect(plan.route.destinationName == "Interstellar space")
    #expect(plan.flowState.handleCompletedNavigation(originName: "Earth", waypointName: nil,
                                                     destinationName: "Interstellar space") == .noChange)
    #expect(plan.flowState.handleCompletedNavigation(originName: "Earth", waypointName: nil,
                            destinationName: "Interstellar space", missionID: .voyager1) == .complete)
}
