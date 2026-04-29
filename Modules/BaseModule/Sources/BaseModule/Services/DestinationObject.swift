//
//  DestinationObject.swift
//  OptiUniverse
//
//  Created by Codex on 19.04.2026.
//

import Foundation

public nonisolated struct DestinationObject: Decodable {
    public let id: UUID
    public let object: String
    public let title: String
    public let subtitle: String
    public let imageName: String
    public let tag: String
}
