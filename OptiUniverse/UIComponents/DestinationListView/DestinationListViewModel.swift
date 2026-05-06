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

    private var inFlightTask: Task<[DestinationCardModel], Never>?

    func loadCards() async {
        guard cards.isEmpty,
              let destinationsProvider else {
            return
        }
        if let inFlightTask {
            _ = await inFlightTask.value
            return
        }

        let inFlightTask = Task.detached {
            let destinations = await destinationsProvider.destinations
            return self.map(destinations: destinations)
        }

        self.inFlightTask = inFlightTask
        cards = await inFlightTask.value
        self.inFlightTask = nil
    }

    private nonisolated func map(destinations: [DestinationObject]) -> [DestinationCardModel] {
        destinations.map {
            DestinationCardModel(
                id: $0.id,
                object: $0.object,
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
