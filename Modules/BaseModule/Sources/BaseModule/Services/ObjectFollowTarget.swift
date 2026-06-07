//
//  ObjectFollowTarget.swift
//  OptiUniverse
//
//  Created by Codex on 07.06.2026.
//

public nonisolated struct ObjectFollowTarget: Equatable, Sendable {
    public let bodyName: String
    public let surfaceLocation: SurfaceLocation?

    public init(bodyName: String,
                surfaceLocation: SurfaceLocation? = nil) {
        self.bodyName = bodyName
        self.surfaceLocation = surfaceLocation
    }
}
