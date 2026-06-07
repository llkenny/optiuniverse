import Foundation
import SwiftUI
import Testing
@testable import OptiUniverse

@MainActor
struct HeroCarouselViewModelTests {
    @Test func mapsFeaturedObjectsAndClampsIndexes() async throws {
        let featuredObjects = try decodeFeaturedObjectsFixture()
        let viewModel = HeroCarouselViewModel()
        viewModel.featuredObjectProvider = MockFeaturedObjectProvider(featuredObjects: featuredObjects)

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

    @Test func featuredMoonBaseUsesDestinationID() async throws {
        let viewModel = HeroCarouselViewModel()
        viewModel.featuredObjectProvider = MockFeaturedObjectProvider(
            featuredObjects: try decodeFeaturedObjectsFixture()
        )

        await viewModel.loadCards()

        let card = try #require(viewModel.cards.first { $0.title == "Moon Base" })
        let destination = try #require(try decodeDestinationsFixture().first { $0.title == "Moon Base" })

        #expect(card.id == destination.id)
    }

    @Test func nonSurfaceHeroCardUsesDestinationID() async throws {
        let viewModel = HeroCarouselViewModel()
        viewModel.featuredObjectProvider = MockFeaturedObjectProvider(
            featuredObjects: try decodeFeaturedObjectsFixture()
        )

        await viewModel.loadCards()

        let card = try #require(viewModel.cards.first { $0.title == "Mars" })
        let destination = try #require(try decodeDestinationsFixture().first { $0.title == "Mars" })

        #expect(card.id == destination.id)
    }
}
