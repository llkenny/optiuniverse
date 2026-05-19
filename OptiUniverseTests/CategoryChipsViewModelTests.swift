import Testing
@testable import OptiUniverse

@MainActor
struct CategoryChipsViewModelTests {
    @Test func preservesFirstSeenUniqueTagOrder() async throws {
        let destinations = try decodeDestinationsFixture()
        let viewModel = CategoryChipsViewModel()
        viewModel.destinationsProvider = MockDestinationsProvider(destinations: destinations)

        await viewModel.loadTags()

        #expect(viewModel.tags == ["Hot", "Inhabited"])
    }
}
