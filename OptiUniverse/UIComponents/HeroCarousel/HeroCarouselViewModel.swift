//
//  HeroCarouselViewModel.swift
//  OptiUniverse
//
//  Created by max on 09.04.2026.
//

import SwiftUI

@Observable
final class HeroCarouselViewModel {
    
    var activeCardID: HeroCard.ID?
    var cards: [HeroCard] = []
    
    func loadCards() {
        let featuredObjects: [FeaturedObject] = Bundle.main.loadConfig(filename: "FeaturedObjects")
        cards = featuredObjects.map {
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
}
