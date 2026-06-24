//
//  RenderPreparationPipeline.swift
//  OptiUniverse
//
//  Created by Codex on 25.04.2026.
//

import simd

@MainActor
final class RenderPreparationPipeline: PreparedRenderSnapshotProviding {
    private let planets: [Planet]
    private var inFlightTask: Task<Void, Never>?
    private var pendingSimulationTime: Float?
    private var nextFrameID: UInt64 = 0
    private var presentationMetricsByBodyName: [String: CelestialBodyPresentationMetrics] = [:]

    private(set) var latestSnapshot: PreparedRenderSnapshot?

    init(planets: [Planet]) {
        self.planets = planets
    }

    deinit {
        inFlightTask?.cancel()
    }

    func requestPreparation(simulationTime: Float) {
        pendingSimulationTime = simulationTime

        guard inFlightTask == nil else { return }

        inFlightTask = Task { @MainActor [weak self] in
            await self?.drainPendingPreparations()
        }
    }

    func setPresentationMetrics(_ metrics: [String: CelestialBodyPresentationMetrics]) {
        presentationMetricsByBodyName = metrics
    }

    private func drainPendingPreparations() async {
        defer { inFlightTask = nil }

        while let simulationTime = pendingSimulationTime {
            pendingSimulationTime = nil

            let frameID = nextFrameID
            nextFrameID += 1

            await prepareSnapshot(frameID: frameID,
                                  simulationTime: simulationTime)

            guard !Task.isCancelled else { return }
        }
    }

    private func prepareSnapshot(frameID: UInt64, simulationTime: Float) async {
        var packets: [PreparedPlanetRenderPacket] = []
        packets.reserveCapacity(planets.count)
        var worldPositionsByName: [String: SIMD3<Float>] = [:]

        for planet in planets {
            guard !Task.isCancelled else { return }

            let parentWorldPosition = planet.parentName
                .flatMap { worldPositionsByName[$0] }
            let baseModelMatrix = planet.modelMatrix(at: simulationTime,
                                                     parentWorldPosition: parentWorldPosition)
            let normalizedScale = planet.radius
            let worldModelMatrix = baseModelMatrix
                * float4x4.makeScale(SIMD3<Float>(repeating: normalizedScale))
            guard let presentationMetrics = presentationMetricsByBodyName[planet.name] else {
                continue
            }
            let worldPosition4 = baseModelMatrix * SIMD4<Float>(0, 0, 0, 1)
            let worldPosition = SIMD3<Float>(worldPosition4.x,
                                             worldPosition4.y,
                                             worldPosition4.z)
            worldPositionsByName[planet.name] = worldPosition

            packets.append(
                PreparedPlanetRenderPacket(
                    planetName: planet.name,
                    baseModelMatrix: baseModelMatrix,
                    worldModelMatrix: worldModelMatrix,
                    normalizedScale: normalizedScale,
                    framingRadius: presentationMetrics.framingRadius,
                    surfaceRadius: presentationMetrics.surfaceRadius,
                    worldPosition: worldPosition
                )
            )
        }

        guard !Task.isCancelled else { return }
        latestSnapshot = PreparedRenderSnapshot(frameID: frameID,
                                                simulationTime: simulationTime,
                                                planets: packets)
    }
}

extension Planet {
    nonisolated func modelMatrix(at time: Float,
                                 parentWorldPosition: SIMD3<Float>? = nil) -> float4x4 {
        let orbitAngle = time * orbitSpeed
        let orbitRotation = float4x4.makeRotationZ(orbitAngle)
        let orbitalTranslation = float4x4.makeTranslation([distance, 0, 0])
        let selfSpin = float4x4.makeRotationZ(time * rotationSpeedKmSec)
        let parentTranslation = float4x4.makeTranslation(parentWorldPosition ?? .zero)

        // Transformations are applied right to left.
        return parentTranslation * orbitRotation * orbitalTranslation * selfSpin
    }
}
