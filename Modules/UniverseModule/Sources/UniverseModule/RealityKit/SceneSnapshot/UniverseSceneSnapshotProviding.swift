//
//  UniverseSceneSnapshotProviding.swift
//  UniverseModule
//
//  Created by max on 24.05.2026.
//

@MainActor
protocol UniverseSceneSnapshotProviding: AnyObject {
    var latestSnapshot: UniverseSceneSnapshot? { get }
    var preparationError: CelestialStateError? { get }
    var hasPresentationMetrics: Bool { get }
    func setPresentationTime(_ time: Float)
    func requestPreparation(simulationTime: Double)
}

extension UniverseSceneSnapshotProviding {
    var preparationError: CelestialStateError? { nil }
    var hasPresentationMetrics: Bool { true }
    func setPresentationTime(_ time: Float) {}
}
