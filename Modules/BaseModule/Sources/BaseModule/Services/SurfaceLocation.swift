//
//  SurfaceLocation.swift
//  BaseModule
//
//  Created by Codex on 06.06.2026.
//

public nonisolated struct SurfaceLocation: Decodable, Equatable, Sendable {
    public let bodyName: String
    public let latitudeDegrees: Float
    public let longitudeDegrees: Float
}
