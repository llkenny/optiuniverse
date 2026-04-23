//
//  DestinationObject.swift
//  OptiUniverse
//
//  Created by Codex on 19.04.2026.
//

import Foundation

struct DestinationObject: Decodable {
    let id: UUID
    let title: String
    let subtitle: String
    let imageName: String
    let tag: String
}
