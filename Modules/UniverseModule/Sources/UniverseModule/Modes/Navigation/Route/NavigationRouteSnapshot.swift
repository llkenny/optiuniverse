//
//  NavigationRouteSnapshot.swift
//  UniverseModule
//
//  Created by Codex on 07.09.2026.
//

import Foundation

/// Public, lightweight snapshot of navigation state.
///
/// `NavigationRouteSnapshot` is necessary because views and facades need navigation progress and timing
/// without depending on route geometry or coordinator internals. It is published by
/// `NavigationRouteCoordinator` and stored by `UniverseModuleResources`.
///
/// Ownership:
/// - Produced by the route coordinator whenever lifecycle/progress state changes.
/// - Consumed outside the navigation mode as immutable value data.
/// - Does not grant access to mutable route or camera ownership.
public struct NavigationRouteSnapshot: Sendable, Equatable {
    public let routeID: UUID?
    public let state: NavigationRouteState
    public let originName: String?
    public let waypointName: String?
    public let destinationName: String?
    public let progress: Float
    public let elapsedTime: TimeInterval
    public let remainingTime: TimeInterval
    public let estimatedDuration: TimeInterval

    public static let idle = NavigationRouteSnapshot(routeID: nil,
                                                     state: .idle,
                                                     originName: nil,
                                                     waypointName: nil,
                                                     destinationName: nil,
                                                     progress: 0,
                                                     elapsedTime: 0,
                                                     remainingTime: 0,
                                                     estimatedDuration: 0)
}
