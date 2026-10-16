import Foundation
import Testing
import UniverseModule
@testable import OptiUniverse

@MainActor
struct HeroCarouselViewModelTests {
    @Test func sortsMissionsAndInitiallySelectsNewest() {
        let viewModel = HeroCarouselViewModel(missions: [.artemisII, .crew13, .starshipFlight14])

        #expect(viewModel.totalCount == 3)
        #expect(viewModel.cards.map(\.mission) == [.crew13, .starshipFlight14, .artemisII])
        #expect(viewModel.activeCardID == Mission.crew13.id)
        #expect(viewModel.currentIndex == 0)
    }

    @Test func indicatorSelectionAndScrollingStayInSync() {
        let viewModel = HeroCarouselViewModel()
        viewModel.currentIndex = 1
        #expect(viewModel.activeCardID == Mission.starshipFlight14.id)
        viewModel.activeCardID = Mission.artemisII.id
        #expect(viewModel.currentIndex == 2)
        #expect(viewModel.index(for: viewModel.cardID(for: 1)) == 1)
    }

    @Test func clampsOutOfRangeSelection() {
        let viewModel = HeroCarouselViewModel()
        viewModel.currentIndex = -1
        #expect(viewModel.currentIndex == 0)
        #expect(viewModel.activeCardID == Mission.crew13.id)
        viewModel.currentIndex = 99
        #expect(viewModel.currentIndex == 2)
        #expect(viewModel.activeCardID == Mission.artemisII.id)
        #expect(viewModel.index(for: "unknown-mission") == nil)
        #expect(viewModel.index(for: nil) == nil)
    }

    @Test func emptyCatalogHasNoSelection() {
        let viewModel = HeroCarouselViewModel(missions: [])
        viewModel.currentIndex = 99
        #expect(viewModel.totalCount == 0)
        #expect(viewModel.cards.isEmpty)
        #expect(viewModel.activeCardID == nil)
        #expect(viewModel.currentIndex == 0)
        #expect(viewModel.clampedIndex(for: 0) == nil)
        #expect(viewModel.cardID(for: 0) == nil)
    }

    @Test func launchDateUsesRequestedLocaleAndUTC() {
        let card = MissionCardModel(mission: .crew13)
        #expect(card.formattedLaunchDate(locale: Locale(identifier: "en_US")) == "Oct 1, 2026")
        #expect(card.formattedLaunchDate(locale: Locale(identifier: "en_GB")) == "1 Oct 2026")
        #expect(card.mission.launchDate == card.mission.flightPlan.launchDate)
    }
}
