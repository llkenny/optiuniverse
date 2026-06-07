//
//  FeaturedObject.swift
//  OptiUniverse
//
//  Created by max on 09.04.2026.
//

import Foundation

public nonisolated struct FeaturedObject: Decodable, Sendable {

    public struct AccentColor: Decodable, Sendable {
        public let red: Double
        public let green: Double
        public let blue: Double
    }

    public let id: UUID
    public let name: String
    public let description: String
    public let imageName: String
    public let accentColor: [AccentColor]
    public let surfaceLocation: SurfaceLocation?
}
