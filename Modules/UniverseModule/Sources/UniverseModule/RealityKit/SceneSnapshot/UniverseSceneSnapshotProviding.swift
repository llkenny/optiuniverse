//
//  UniverseSceneSnapshotProviding.swift
//  UniverseModule
//
//  Created by max on 24.05.2026.
//

@MainActor
protocol UniverseSceneSnapshotProviding: AnyObject {
    var latestSnapshot: UniverseSceneSnapshot? { get }
    func requestPreparation(simulationTime: Float)
}
