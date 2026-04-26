//
//  RenderPreparationPipeline.swift
//  OptiUniverse
//
//  Created by Codex on 25.04.2026.
//

import Foundation
import simd

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

struct PreparedPlanetRenderPacket: Sendable {
    let planetName: String
    let meshes: [LoadedMesh]
    let baseModelMatrix: float4x4
    let worldModelMatrix: float4x4
    let normalizedScale: Float
    let primaryMeshRadius: Float
    let framingRadius: Float
    let worldPosition: SIMD3<Float>
}

@MainActor
final class RenderPreparationPipeline {
    private let modelLoader: ModelLoader
    private let planets: [Planet]
    private var meshCache: [String: [LoadedMesh]] = [:]
    private var inFlightTask: Task<Void, Never>?
    private var nextFrameID: UInt64 = 0

    private(set) var latestSnapshot: PreparedRenderSnapshot?

    init(modelLoader: ModelLoader, planets: [Planet]) {
        self.modelLoader = modelLoader
        self.planets = planets
    }

    deinit {
        inFlightTask?.cancel()
    }

    func requestPreparation(simulationTime: Float) {
        guard inFlightTask == nil else { return }

        let frameID = nextFrameID
        nextFrameID += 1

        inFlightTask = Task { @MainActor [weak self] in
            await self?.prepareSnapshot(frameID: frameID,
                                        simulationTime: simulationTime)
        }
    }

    private func prepareSnapshot(frameID: UInt64, simulationTime: Float) async {
        defer { inFlightTask = nil }

        var packets: [PreparedPlanetRenderPacket] = []
        packets.reserveCapacity(planets.count)

        for planet in planets {
            guard !Task.isCancelled else { return }

            let meshes = await loadedMeshes(for: planet)
            let baseModelMatrix = planet.modelMatrix(at: simulationTime)
            let primaryMeshRadius = meshes.first?.boundsRadius ?? 1
            let normalizedScale = primaryMeshRadius > 0
                ? planet.radius / primaryMeshRadius
                : planet.radius
            let worldModelMatrix = baseModelMatrix
                * float4x4.makeScale(SIMD3<Float>(repeating: normalizedScale))
            let maxMeshRadius = meshes.map(\.boundsRadius).max() ?? primaryMeshRadius
            let framingRadius = maxMeshRadius > 0
                ? maxMeshRadius * normalizedScale
                : planet.radius
            let worldPosition4 = baseModelMatrix * SIMD4<Float>(0, 0, 0, 1)

            packets.append(
                PreparedPlanetRenderPacket(
                    planetName: planet.name,
                    meshes: meshes,
                    baseModelMatrix: baseModelMatrix,
                    worldModelMatrix: worldModelMatrix,
                    normalizedScale: normalizedScale,
                    primaryMeshRadius: primaryMeshRadius,
                    framingRadius: framingRadius,
                    worldPosition: SIMD3<Float>(worldPosition4.x,
                                                worldPosition4.y,
                                                worldPosition4.z)
                )
            )
        }

        guard !Task.isCancelled else { return }
        latestSnapshot = PreparedRenderSnapshot(frameID: frameID,
                                                simulationTime: simulationTime,
                                                planets: packets)
    }

    private func loadedMeshes(for planet: Planet) async -> [LoadedMesh] {
        if let cachedMeshes = meshCache[planet.name] {
            return cachedMeshes
        }

        let loadedMeshes = await modelLoader.getMeshes(for: planet.name,
                                                       primaryMeshName: planet.meshName)
        meshCache[planet.name] = loadedMeshes
        return loadedMeshes
    }
}

extension Planet {
    nonisolated func modelMatrix(at time: Float) -> float4x4 {
        let orbitAngle = time * orbitSpeed
        let orbitRotation = float4x4.makeRotationZ(orbitAngle)
        let orbitalTranslation = float4x4.makeTranslation([distance, 0, 0])
        let selfSpin = float4x4.makeRotationZ(time * rotationSpeedKmSec)

        // Transformations are applied right to left.
        return orbitRotation * orbitalTranslation * selfSpin
    }
}
