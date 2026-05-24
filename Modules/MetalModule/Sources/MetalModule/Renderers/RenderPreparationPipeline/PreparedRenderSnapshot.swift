//
//  PreparedRenderSnapshot.swift
//  MetalModule
//
//  Created by max on 24.05.2026.
//

// Immutable per-frame render input prepared before Metal command encoding.
// Keeps async mesh/model lookup out of the synchronous render pass.
struct PreparedRenderSnapshot: Sendable {
    let frameID: UInt64
    let simulationTime: Float
    let planets: [PreparedPlanetRenderPacket]

    nonisolated func planet(named name: String) -> PreparedPlanetRenderPacket? {
        planets.first { $0.planetName == name }
    }

    nonisolated func framingRadius(ofPlanetNamed name: String) -> Float? {
        planet(named: name)?.framingRadius
    }

    nonisolated func worldPosition(ofPlanetNamed name: String) -> SIMD3<Float>? {
        planet(named: name)?.worldPosition
    }
}
