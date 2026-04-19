//
//  DestinationListViewModel.swift
//  OptiUniverse
//
//  Created by max on 19.04.2026.
//

import SwiftUI

@Observable
final class DestinationListViewModel {
    
    var cards: [DestinationCardModel] = []
    
    func loadCards() {
        guard cards.isEmpty else {
            return
        }
        
        let destinationObjects: [DestinationObject] = Bundle.main.loadConfig(filename: "DestinationObjects")
        cards = destinationObjects.map {
            DestinationCardModel(
                id: $0.id,
                title: $0.title,
                subtitle: $0.subtitle,
                imageResource: ImageResource(name: $0.imageName, bundle: .main)
            )
        }
    }
}
