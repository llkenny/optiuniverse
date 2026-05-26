//
//  NavigationController.swift
//  MetalModule
//
//  Created by max on 25.05.2026.
//

import CoreGraphics
import Foundation
import simd

enum NavigationCameraUpdate: Equatable {
    case inactive
    case customLookAt
    case standardCameraState
    case noCameraChange
}

/// Owns route navigation state and navigation-specific camera behavior.
@MainActor
final class NavigationController {
    let navigationStatePublisher: NavigationRenderStatePublishing
    let navigationRouteCoordinator: NavigationRouteCoordinator
    unowned let snapshotProvider: SnapshotProvider
    unowned let cameraState: CameraState
    let navigationCameraMode: NavigationCameraMode
    let planets: [Planet]
    let viewportSize: () -> CGSize

    var followPlanet: ((String) -> Void)?

    var cameraTransition: CameraTransition?
    var pendingNavigationDestinationName: String?
    var navigationCameraTrailingOffset = SIMD3<Float>(0, 0, 0.18)
    var navigationArrivalRouteID: UUID?
    var navigationArrivalStartCameraPosition = SIMD3<Float>(repeating: 0)
    var navigationArrivalStartTarget = SIMD3<Float>(repeating: 0)
    var navigationArrivalTargetOffset = SIMD3<Float>(0, 0, 1)
    var navigationArrivalProgress: Float = 1
    let navigationArrivalDuration: Float = 0.9
    let navigationArrivalDistanceMultiplier: Float = 5.8

    var navigationCameraFollowEnabled = true

    var navigationSnapshot: NavigationRouteSnapshot {
        navigationStatePublisher.navigationSnapshot
    }

    var routeRenderState: NavigationRouteRenderState {
        NavigationRouteRenderState(route: navigationRouteCoordinator.activeRouteForRendering,
                                   progress: navigationRouteCoordinator.renderProgress,
                                   elapsedTime: navigationRouteCoordinator.elapsedTime)
    }

    var isNavigationActive: Bool {
        navigationRouteCoordinator.isNavigationActive
    }

    var controlsCamera: Bool {
        isNavigationActive || cameraTransition != nil
    }

    init(navigationStatePublisher: NavigationRenderStatePublishing,
         snapshotProvider: SnapshotProvider,
         cameraState: CameraState,
         planets: [Planet],
         viewportSize: @escaping () -> CGSize) {
        self.navigationStatePublisher = navigationStatePublisher
        self.snapshotProvider = snapshotProvider
        self.cameraState = cameraState
        self.planets = planets
        self.viewportSize = viewportSize
        navigationCameraMode = NavigationCameraMode(cameraState: cameraState)
        navigationRouteCoordinator = NavigationRouteCoordinator { [weak navigationStatePublisher] snapshot in
            navigationStatePublisher?.publishNavigationSnapshot(snapshot)
        }
    }

    func update(snapshot: PreparedRenderSnapshot?,
                delta: Float) -> NavigationCameraUpdate {
        if let snapshot,
           let name = pendingNavigationDestinationName,
           applyNavigation(named: name, snapshot: snapshot) {
            pendingNavigationDestinationName = nil
        }

        navigationRouteCoordinator.update()

        if let snapshot {
            refreshActiveRoute(snapshot: snapshot)
            return updateNavigationCamera(snapshot: snapshot,
                                          delta: delta)
        }

        return controlsCamera ? .noCameraChange : .inactive
    }

    func beginManualCameraControl() {
        if navigationRouteCoordinator.isNavigationActive,
           navigationCameraFollowEnabled {
            setNavigationCameraFollowEnabled(false)
        }
    }
}
