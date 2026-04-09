//
//  HeroCard.swift
//  OptiUniverse
//
//  Created by max on 09.04.2026.
//

import SwiftUI

struct HeroCard: Identifiable {
    let id: UUID
    let imageResource: ImageResource
    let title: String
    let subtitle: String
    let accentColors: [Color]
}
