//
//  HeroCarouselViewModel.swift
//  OptiUniverse
//
//  Created by max on 09.04.2026.
//

import SwiftUI
internal import CommonTools

@Observable
final class HeroCarouselViewModel {

    enum Constants {
        static let filename = "FeaturedObjects"
        static let urlString = "https://api.kb404.com/static/FeaturedObjects.json"
    }

    var activeCardID: HeroCard.ID?
    var cards: [HeroCard] = []

    var totalCount: Int {
        cards.count
    }

    private var inFlightTask: Task<[HeroCard], Never>?

    func loadCards() async {
        guard cards.isEmpty,
              inFlightTask == nil else {
            // Only single load. Subsequent should listen for cards value.
            return
        }

        let inFlightTask = Task.detached {
            await self.fetchCards()
        }

        self.inFlightTask = inFlightTask
        cards = await inFlightTask.value
        self.inFlightTask = nil
    }

    private nonisolated func fetchCards() async -> [HeroCard] {
        let featuredObjects: [FeaturedObject]

        let remoteObjects = try? await [FeaturedObject]
            .loadFromRemoteConfig(from: Constants.urlString)

        if let remoteObjects, !remoteObjects.isEmpty {
            featuredObjects = remoteObjects
        } else {
            featuredObjects = await Bundle.main.loadConfig(filename: Constants.filename)
        }

        return featuredObjects.map {
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
