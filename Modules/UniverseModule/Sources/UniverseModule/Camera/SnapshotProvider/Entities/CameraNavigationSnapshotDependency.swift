//
//  CameraNavigationSnapshotDependency.swift
//  UniverseModule
//
//  Created by max on 31.05.2026.
//

import Foundation

struct CameraNavigationSnapshotDependency: Equatable {
    let routeID: UUID?
    let destinationName: String?
    let progress: Float
    let state: NavigationRouteState
    let hasActiveTransition: Bool
    let arrivalProgress: Float
}
