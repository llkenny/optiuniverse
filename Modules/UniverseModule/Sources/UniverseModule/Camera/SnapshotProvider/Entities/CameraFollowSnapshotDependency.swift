//
//  CameraFollowSnapshotDependency.swift
//  UniverseModule
//
//  Created by max on 31.05.2026.
//

struct CameraFollowSnapshotDependency: Equatable {
    let planetName: String
    let worldPosition: SIMD3<Float>?
    let framingRadius: Float?
    let hasActiveTransition: Bool
}
