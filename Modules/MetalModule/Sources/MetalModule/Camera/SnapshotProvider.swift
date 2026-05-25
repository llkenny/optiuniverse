//
//  SnapshotProvider.swift
//  MetalModule
//
//  Created by max on 22.05.2026.
//

/// Reads committed camera state, scene snapshots, viewport data, and time-dependent mode requirements.
/// It produces immutable camera snapshots containing render-ready matrices and derived camera values.
@MainActor
final class SnapshotProvider {
    private let snapshotSource: PreparedRenderSnapshotProviding

    init(snapshotSource: PreparedRenderSnapshotProviding) {
        self.snapshotSource = snapshotSource
    }

    var latestSnapshot: PreparedRenderSnapshot? {
        snapshotSource.latestSnapshot
    }

    func requestPreparation(simulationTime: Float) {
        snapshotSource.requestPreparation(simulationTime: simulationTime)
    }
}
