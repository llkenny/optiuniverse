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
        // TODO: Implement json, same as FeaturedObjects
        // TODO: Fix Codex warning
//        loadCards() is invoked unconditionally in .onAppear, but DestinationListViewModel.loadCards() creates every DestinationCardModel with a fresh UUID (id: .init()). When this screen appears again (for example after navigating away and back), all item identities change and ForEach treats the list as brand-new content, which can reset scroll position and cause visible churn. Guard this call (or make IDs stable) so item identity persists across appearances.
        cards = [
            DestinationCardModel(id: .init(),
                                 title: "Mars mountains",
                                 subtitle: "Dusty Red Planet",
                                 imageResource: .marsPerseveranceZR008120739017260428EBYN0391170ZCAM036710340LMJ),
            DestinationCardModel(id: .init(),
                                 title: "Neptune Scooter",
                                 subtitle: "Windy Blue Planet",
                                 imageResource: .pia01142Orig),
            DestinationCardModel(id: .init(),
                                 title: "Lunar landscape",
                                 subtitle: "Nearest destination to Earth",
                                 imageResource: .s21280),
            DestinationCardModel(id: .init(),
                                 title: "Lunar landscape",
                                 subtitle: "Nearest destination to Earth",
                                 imageResource: .s21280)
        ]
    }
}
