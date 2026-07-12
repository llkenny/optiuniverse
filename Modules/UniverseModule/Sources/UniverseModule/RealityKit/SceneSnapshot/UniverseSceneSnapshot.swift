//
//  UniverseSceneSnapshot.swift
//  UniverseModule
//
//  Created by max on 24.05.2026.
//

// Immutable per-frame scene state consumed by camera, route, and RealityKit updates.
struct UniverseSceneSnapshot: Sendable {
    let frameID: UInt64
    let simulationTime: Float
    let planets: [CelestialBodySnapshot]

    nonisolated func planet(named name: String) -> CelestialBodySnapshot? {
        planets.first { $0.planetName == name }
    }

    nonisolated func framingRadius(ofPlanetNamed name: String) -> Float? {
        planet(named: name)?.framingRadius
    }

    nonisolated func surfaceRadius(ofPlanetNamed name: String) -> Float? {
        planet(named: name)?.surfaceRadius
    }

    nonisolated func worldPosition(ofPlanetNamed name: String) -> SIMD3<Float>? {
        planet(named: name)?.worldPosition
    }
}
