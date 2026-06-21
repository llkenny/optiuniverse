//
//  MetalSceneOwnershipControls.swift
//  UniverseModule
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
    static func migration(realityKitBodyNames: Set<String> = [],
                          stageFourContentPrepared: Bool = false) -> MetalSceneOwnershipControls {
        var suppressedSubsystems = Set(realityKitBodyNames.map(Subsystem.celestialBody(named:)))
        if stageFourContentPrepared {
            suppressedSubsystems.formUnion([
                .environment,
                .starField,
                .transferOrbit,
                .navigationRoute,
                .navigationMarker
            ])
        }
        return MetalSceneOwnershipControls(
            suppressedSubsystems: suppressedSubsystems
        )
    }

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
