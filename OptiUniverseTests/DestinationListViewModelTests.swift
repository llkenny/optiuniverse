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

        #expect(viewModel.cards(filteredBy: nil).map(\.title) == ["Moon Base", "Mercury", "Earth", "Mars"])
        #expect(viewModel.cards(filteredBy: "Hot").map(\.title) == ["Mercury", "Mars"])
        #expect(viewModel.cards(filteredBy: "Inhabited").map(\.title) == ["Earth"])
        #expect(viewModel.cards(filteredBy: "Base").map(\.title) == ["Moon Base"])
        #expect(viewModel.cards(filteredBy: "Missing").isEmpty)
    }

    @Test func moonBaseCardPreservesSurfaceFollowTarget() async throws {
        let viewModel = DestinationListViewModel()
        viewModel.destinationsProvider = MockDestinationsProvider(
            destinations: try decodeDestinationsFixture()
        )

        await viewModel.loadCards()

        let card = try #require(viewModel.cards(filteredBy: nil).first { $0.title == "Moon Base" })
        let surfaceLocation = try #require(card.surfaceLocation)
        let followTarget = card.followTarget

        #expect(card.object == "Moon")
        #expect(surfaceLocation.bodyName == "Moon")
        #expect(surfaceLocation.latitudeDegrees == -90)
        #expect(surfaceLocation.longitudeDegrees == 0)
        #expect(followTarget.bodyName == "Moon")
        #expect(followTarget.surfaceLocation == surfaceLocation)
    }

    @Test func nonSurfaceDestinationCardFollowsItsObject() {
        let card = DestinationCardModel(
            id: UUID(),
            object: "Mars",
            title: "Mars Research",
            subtitle: "Red world",
            imageResource: .dstMars,
            tag: "Hot"
        )
        let followTarget = card.followTarget

        #expect(followTarget.bodyName == "Mars")
        #expect(followTarget.surfaceLocation == nil)
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
