//
//  MetalSceneOwnershipControls.swift
//  MetalModule
//
//  Created by Codex on 18.06.2026.
//

struct MetalSceneOwnershipControls: Sendable {
    enum Subsystem: Hashable, Sendable {
        case environment
        case starField
        case celestialBody(named: String)
        case transferOrbit
        case navigationRoute
        case navigationMarker
    }

    /// Migration source control. Add a subsystem here after RealityKit takes ownership of its draw.
    static let migration = MetalSceneOwnershipControls(suppressedSubsystems: [])

    private let suppressedSubsystems: Set<Subsystem>

    init(suppressedSubsystems: Set<Subsystem>) {
        self.suppressedSubsystems = suppressedSubsystems
    }

    func renders(_ subsystem: Subsystem) -> Bool {
        !suppressedSubsystems.contains(subsystem)
    }

    func rendersCelestialBody(named name: String) -> Bool {
        renders(.celestialBody(named: name))
    }
}
