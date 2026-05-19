import Testing
@testable import OptiUniverse

@MainActor
struct DestinationListViewModelTests {
    @Test func mapsAndFiltersCards() async throws {
        let destinations = try decodeDestinationsFixture()
        let viewModel = DestinationListViewModel()
        viewModel.destinationsProvider = MockDestinationsProvider(destinations: destinations)

        await viewModel.loadCards()

        #expect(viewModel.cards(filteredBy: nil).map(\.title) == ["Mercury", "Earth", "Mars"])
        #expect(viewModel.cards(filteredBy: "Hot").map(\.title) == ["Mercury", "Mars"])
        #expect(viewModel.cards(filteredBy: "Inhabited").map(\.title) == ["Earth"])
        #expect(viewModel.cards(filteredBy: "Missing").isEmpty)
    }
}
