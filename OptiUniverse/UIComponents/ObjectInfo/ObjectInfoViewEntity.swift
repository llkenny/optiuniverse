//
//  ObjectInfoViewEntity.swift
//  OptiUniverse
//
//  Created by max on 11.05.2026.
//

import Foundation

struct ObjectInfoViewEntity: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let description: String
    let navigationButtonTitle: String
    let navigationButtonAction: () -> Void
}
