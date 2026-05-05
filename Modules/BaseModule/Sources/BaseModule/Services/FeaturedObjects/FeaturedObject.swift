//
//  FeaturedObject.swift
//  OptiUniverse
//
//  Created by max on 09.04.2026.
//

import Foundation

public nonisolated struct FeaturedObject: Decodable, Sendable {
    // swiftlint:disable identifier_name
    public struct AccentColor: Decodable, Sendable {
        public let r: Double
        public let g: Double
        public let b: Double
    }
    // swiftlint:enable identifier_name

    public let id: UUID
    public let name: String
    public let description: String
    public let imageName: String
    public let accentColor: [AccentColor]
}
