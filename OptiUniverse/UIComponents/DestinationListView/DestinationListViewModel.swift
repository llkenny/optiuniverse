//
//  DestinationListViewModel.swift
//  OptiUniverse
//
//  Created by max on 19.04.2026.
//

import SwiftUI
import BaseModule

@Observable
final class DestinationListViewModel {
    private var cards: [DestinationCardModel] = []
    var destinationsProvider: DestinationsProviderProtocol?

    func loadCards() {
        guard cards.isEmpty,
              let destinationsProvider else {
            return
        }

        let destinations = destinationsProvider.destinations
        cards = map(destinations: destinations)
    }

    private func map(destinations: [DestinationObject]) -> [DestinationCardModel] {
        destinations.map {
            DestinationCardModel(
                id: $0.id,
                title: $0.title,
                subtitle: $0.subtitle,
                imageResource: ImageResource(name: $0.imageName, bundle: .main),
                tag: $0.tag
            )
        }
    }

    func cards(filteredBy categoryTitle: String?) -> [DestinationCardModel] {
        guard let categoryTitle else {
            return cards
        }

        return cards.filter { $0.tag == categoryTitle }
    }
}
