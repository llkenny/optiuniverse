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
    var destinationsProvider: DestinationsProviderProtocol?

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

        let featuredObjects = featuredObjectProvider.featuredObjects
        cards = map(featuredObjects: featuredObjects,
                    destinations: destinationsProvider?.destinations ?? [])
    }

    private func map(featuredObjects: [FeaturedObject],
                     destinations: [DestinationObject]) -> [HeroCard] {
        featuredObjects.map { featuredObject in
            let matchingDestination = destinations.first {
                $0.title == featuredObject.name || $0.object == featuredObject.name
            }

            return HeroCard(
                id: featuredObject.id,
                imageResource: ImageResource(name: featuredObject.imageName, bundle: .main),
                title: featuredObject.name,
                subtitle: featuredObject.description,
                accentColors: featuredObject.accentColor.map { color in
                    Color(red: color.red, green: color.green, blue: color.blue)
                },
                surfaceLocation: matchingDestination?.surfaceLocation
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
