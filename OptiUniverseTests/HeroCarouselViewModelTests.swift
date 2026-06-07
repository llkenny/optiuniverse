import Foundation
import SwiftUI
import Testing
@testable import OptiUniverse

@MainActor
struct HeroCarouselViewModelTests {
    @Test func mapsFeaturedObjectsAndClampsIndexes() async throws {
        let featuredObjects = try decodeFeaturedObjectsFixture()
        let destinations = try decodeDestinationsFixture()
        let viewModel = HeroCarouselViewModel()
        viewModel.featuredObjectProvider = MockFeaturedObjectProvider(featuredObjects: featuredObjects)
        viewModel.destinationsProvider = MockDestinationsProvider(destinations: destinations)

        #expect(viewModel.clampedIndex(for: 0) == nil)
        #expect(viewModel.cardID(for: 0) == nil)
        #expect(viewModel.index(for: nil) == nil)

        await viewModel.loadCards()

        #expect(viewModel.totalCount == 4)
        #expect(viewModel.cards.map(\.title) == ["Moon Base", "Saturn", "Neptune", "Mars"])
        #expect(viewModel.cards.map(\.subtitle) == [
            "First lunar outpost",
            "Ringed giant",
            "Deep blue frontier",
            "Red world"
        ])
        #expect(viewModel.clampedIndex(for: -1) == 0)
        #expect(viewModel.clampedIndex(for: 99) == 3)

        let secondID = try #require(viewModel.cardID(for: 1))
        #expect(viewModel.index(for: secondID) == 1)
    }

    @Test func featuredMoonBaseResolvesSurfaceLocationFromDestination() async throws {
        let viewModel = HeroCarouselViewModel()
        viewModel.featuredObjectProvider = MockFeaturedObjectProvider(
            featuredObjects: try decodeFeaturedObjectsFixture()
        )
        viewModel.destinationsProvider = MockDestinationsProvider(
            destinations: try decodeDestinationsFixture()
        )

        await viewModel.loadCards()

        let card = try #require(viewModel.cards.first { $0.title == "Moon Base" })
        let surfaceLocation = try #require(card.surfaceLocation)
        let followTarget = card.followTarget

        #expect(surfaceLocation.bodyName == "Moon")
        #expect(surfaceLocation.latitudeDegrees == -90)
        #expect(surfaceLocation.longitudeDegrees == 0)
        #expect(followTarget.bodyName == "Moon")
        #expect(followTarget.surfaceLocation == surfaceLocation)
    }

    @Test func nonSurfaceHeroCardFollowsItsTitle() {
        let card = HeroCard(
            id: UUID(),
            imageResource: .dstMars,
            title: "Mars",
            subtitle: "Red world",
            accentColors: [.red]
        )
        let followTarget = card.followTarget

        #expect(followTarget.bodyName == "Mars")
        #expect(followTarget.surfaceLocation == nil)
    }
}
