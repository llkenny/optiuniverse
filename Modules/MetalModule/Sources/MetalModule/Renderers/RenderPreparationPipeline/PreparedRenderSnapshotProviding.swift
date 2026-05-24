//
//  PreparedRenderSnapshotProviding.swift
//  MetalModule
//
//  Created by max on 24.05.2026.
//

@MainActor
protocol PreparedRenderSnapshotProviding: AnyObject {
    var latestSnapshot: PreparedRenderSnapshot? { get }
    func requestPreparation(simulationTime: Float)
}
