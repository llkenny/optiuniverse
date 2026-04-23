//
//  DestinationListViewModel.swift
//  OptiUniverse
//
//  Created by max on 19.04.2026.
//

import SwiftUI

@Observable
final class DestinationListViewModel {
    private var allCards: [DestinationCardModel] = []
    
    func loadCards() {
        guard allCards.isEmpty else {
            return
        }
        
        let destinationObjects: [DestinationObject] = Bundle.main.loadConfig(filename: "DestinationObjects")
        allCards = destinationObjects.map {
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
            return allCards
        }

        return allCards.filter { $0.tag == categoryTitle }
    }
}
