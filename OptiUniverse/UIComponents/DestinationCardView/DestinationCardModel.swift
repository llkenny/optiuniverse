//
//  DestinationCardModel.swift
//  OptiUniverse
//
//  Created by max on 19.04.2026.
//

import DeveloperToolsSupport
import Foundation

struct DestinationCardModel: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let imageResource: ImageResource
    let tag: String
}
