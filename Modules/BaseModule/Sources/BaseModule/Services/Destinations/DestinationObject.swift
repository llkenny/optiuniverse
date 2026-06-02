//
//  DestinationObject.swift
//  OptiUniverse
//
//  Created by Codex on 19.04.2026.
//

import Foundation

public nonisolated struct DestinationObject: Decodable, Sendable {
    public struct Detail: Decodable, Sendable {
        public let title: String
        public let value: String
        public let dimension: String
    }

    public struct OrbitProperties: Decodable, Sendable {
        public let axis: String
        public let eccentricity: String
        public let inclination: String
    }

    public struct OrbitInfo: Decodable, Sendable {
        public let description: String
        public let properties: OrbitProperties
    }

    public let id: UUID
    public let object: String
    public let title: String
    public let subtitle: String
    public let description: String
    public let imageName: String
    public let tag: String
    public let isNavigable: Bool
    public let details: [Detail]
    public let orbitInfo: OrbitInfo?
}
