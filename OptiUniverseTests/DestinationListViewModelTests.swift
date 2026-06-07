import Foundation
import SwiftUI
import Testing
import BaseModule
@testable import OptiUniverse

@MainActor
struct DestinationListViewModelTests {
    @Test func mapsAndFiltersCards() async throws {
        let destinations = try decodeDestinationsFixture()
        let viewModel = DestinationListViewModel()
        viewModel.destinationsProvider = MockDestinationsProvider(destinations: destinations)

        await viewModel.loadCards()

        #expect(viewModel.cards(filteredBy: nil).map(\.title) == [
            "Moon Base",
            "Mercury",
            "Earth",
            "Mars",
            "Saturn",
            "Neptune"
        ])
        #expect(viewModel.cards(filteredBy: "Hot").map(\.title) == ["Mercury", "Mars"])
        #expect(viewModel.cards(filteredBy: "Inhabited").map(\.title) == ["Earth"])
        #expect(viewModel.cards(filteredBy: "Base").map(\.title) == ["Moon Base"])
        #expect(viewModel.cards(filteredBy: "Outer").map(\.title) == ["Saturn", "Neptune"])
        #expect(viewModel.cards(filteredBy: "Missing").isEmpty)
    }

    @Test func moonBaseCardUsesDestinationID() async throws {
        let viewModel = DestinationListViewModel()
        viewModel.destinationsProvider = MockDestinationsProvider(
            destinations: try decodeDestinationsFixture()
        )

        await viewModel.loadCards()

        let card = try #require(viewModel.cards(filteredBy: nil).first { $0.title == "Moon Base" })
        let destination = try #require(try decodeDestinationsFixture().first { $0.title == "Moon Base" })

        #expect(card.id == destination.id)
    }

    @Test func nonSurfaceDestinationCardUsesDestinationID() async throws {
        let viewModel = DestinationListViewModel()
        viewModel.destinationsProvider = MockDestinationsProvider(
            destinations: try decodeDestinationsFixture()
        )

        await viewModel.loadCards()

        let card = try #require(viewModel.cards(filteredBy: nil).first { $0.title == "Mars" })
        let destination = try #require(try decodeDestinationsFixture().first { $0.title == "Mars" })

        #expect(card.id == destination.id)
    }

    @Test func followTargetsWithSameSelectionCarryUniqueRequestIdentifiers() throws {
        let moonBase = try #require(try decodeDestinationsFixture().first { $0.title == "Moon Base" })
        let surfaceLocation = try #require(moonBase.surfaceLocation)
        let firstTarget = ObjectFollowTarget(bodyName: "Moon",
                                             surfaceLocation: surfaceLocation)
        let secondTarget = ObjectFollowTarget(bodyName: "Moon",
                                              surfaceLocation: surfaceLocation)

        #expect(firstTarget.bodyName == secondTarget.bodyName)
        #expect(firstTarget.surfaceLocation == secondTarget.surfaceLocation)
        #expect(firstTarget.requestID != secondTarget.requestID)
        #expect(firstTarget != secondTarget)
    }
}
