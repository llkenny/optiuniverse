//
//  UniverseSceneSnapshotProviding.swift
//  UniverseModule
//
//  Created by max on 24.05.2026.
//

@MainActor
protocol UniverseSceneSnapshotProviding: AnyObject {
    var latestSnapshot: UniverseSceneSnapshot? { get }
    func setPresentationTime(_ time: Float)
    func requestPreparation(simulationTime: Double)
}

extension UniverseSceneSnapshotProviding {
    func setPresentationTime(_ time: Float) {}
}
