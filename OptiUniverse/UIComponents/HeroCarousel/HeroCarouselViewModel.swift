//
//  HeroCarouselViewModel.swift
//  OptiUniverse
//
//  Created by max on 09.04.2026.
//

import SwiftUI

@Observable
final class HeroCarouselViewModel {
    let cards: [MissionCardModel]
    var activeCardID: Mission.ID?

    init(missions: [Mission] = Mission.available) {
        cards = Mission.sortedByLaunchDate(missions).map { MissionCardModel(mission: $0) }
        activeCardID = cards.first?.id
    }

    var totalCount: Int { cards.count }

    var currentIndex: Int {
        get { index(for: activeCardID) ?? 0 }
        set { activeCardID = cardID(for: newValue) }
    }

    func clampedIndex(for index: Int) -> Int? {
        guard !cards.isEmpty else { return nil }
        return min(max(index, 0), cards.count - 1)
    }

    func cardID(for index: Int) -> Mission.ID? {
        guard let clampedIndex = clampedIndex(for: index) else { return nil }
        return cards[clampedIndex].id
    }

    func index(for id: Mission.ID?) -> Int? {
        guard let id else { return nil }
        return cards.firstIndex(where: { $0.id == id })
    }
}
