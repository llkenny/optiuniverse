//
//  ObjectFollowTarget.swift
//  OptiUniverse
//
//  Created by Codex on 07.06.2026.
//

import Foundation

public nonisolated struct ObjectFollowTarget: Equatable, Sendable {
    public let requestID: UUID
    public let bodyName: String
    public let surfaceLocation: SurfaceLocation?

    public init(bodyName: String,
                surfaceLocation: SurfaceLocation? = nil) {
        self.requestID = UUID()
        self.bodyName = bodyName
        self.surfaceLocation = surfaceLocation
    }
}
