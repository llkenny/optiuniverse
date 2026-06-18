//
//  CameraCoordinator+Navigation.swift
//  UniverseModule
//
//  Created by Codex on 27.05.2026.
//

import Foundation
import simd

extension CameraCoordinator: NavigationCameraCoordinating {
    var isNavigationCameraActive: Bool {
        navigationCameraOwner.isActive
    }

    func claimNavigationCameraControl(routeID: UUID) {
        navigationCameraOwner.begin(routeID: routeID)
    }

    func suspendNavigationFollow(routeID: UUID?) {
        navigationCameraOwner.suspend(routeID: routeID)
    }

    func endNavigationCameraControl(routeID: UUID?) {
        navigationCameraOwner.end(routeID: routeID)
    }

    func commitNavigationFollow(route: NavigationRoute,
                                currentPoint: SIMD3<Float>,
                                destinationPosition: SIMD3<Float>,
                                trailingOffset: SIMD3<Float>) {
        navigationCameraOwner.commitFollow(route: route,
                                           currentPoint: currentPoint,
                                           destinationPosition: destinationPosition,
                                           trailingOffset: trailingOffset)
    }

    func commitNavigationArrival(route: NavigationRoute,
                                 position: SIMD3<Float>,
                                 target: SIMD3<Float>) {
        navigationCameraOwner.commitArrival(route: route,
                                            position: position,
                                            target: target)
    }

    func commitNavigationTransition(routeID: UUID,
                                    frame: CameraTransition.Frame) {
        navigationCameraOwner.commitTransition(routeID: routeID,
                                               frame: frame)
    }

    func commitNavigationDestination(destinationPosition: SIMD3<Float>) {
        navigationCameraOwner.commitDestination(destinationPosition: destinationPosition)
    }
}
