//
//  HeroCarouselViewModel.swift
//  OptiUniverse
//
//  Created by max on 09.04.2026.
//

import SwiftUI
import BaseModule

@Observable
final class HeroCarouselViewModel {

    var featuredObjectProvider: FeaturedObjectProviderProtocol?

    var activeCardID: HeroCard.ID?
    var cards: [HeroCard] = []

    var totalCount: Int {
        cards.count
    }

    private var inFlightTask: Task<[HeroCard], Never>?

    func loadCards() async {
        guard cards.isEmpty,
              let featuredObjectProvider else {
            return
        }

        guard inFlightTask == nil else {
            // Someone already started load, no need for a new request — just wait
            return
        }

        let inFlightTask = Task.detached {
            let featuredObjects = await featuredObjectProvider.featuredObjects
            let cards = await self.map(featuredObjects: featuredObjects)
            return cards
        }
        self.inFlightTask = inFlightTask
        cards = await inFlightTask.value
        self.inFlightTask = nil
    }

    private nonisolated func map(featuredObjects: [FeaturedObject]) async -> [HeroCard] {
        featuredObjects.map {
            HeroCard(
                id: $0.id,
                imageResource: ImageResource(name: $0.imageName, bundle: .main),
                title: $0.name,
                subtitle: $0.description,
                accentColors: $0.accentColor.map { color in
                    Color(red: color.r, green: color.g, blue: color.b)
                }
            )
        }
    }

    func clampedIndex(for index: Int) -> Int? {
        guard !cards.isEmpty else { return nil }
        return min(max(index, 0), cards.count - 1)
    }

    func cardID(for index: Int) -> HeroCard.ID? {
        guard let clampedIndex = clampedIndex(for: index) else { return nil }
        return cards[clampedIndex].id
    }

    func index(for id: HeroCard.ID?) -> Int? {
        guard let id else { return nil }
        return cards.firstIndex(where: { $0.id == id })
    }
}
