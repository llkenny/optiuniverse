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

        #expect(viewModel.totalCount == 3)
        #expect(viewModel.cards.map(\.title) == ["Saturn", "Neptune", "Mars"])
        #expect(viewModel.cards.map(\.subtitle) == ["Ringed giant", "Deep blue frontier", "Red world"])
        #expect(viewModel.clampedIndex(for: -1) == 0)
        #expect(viewModel.clampedIndex(for: 99) == 2)

        let secondID = try #require(viewModel.cardID(for: 1))
        #expect(viewModel.index(for: secondID) == 1)
    }
}
