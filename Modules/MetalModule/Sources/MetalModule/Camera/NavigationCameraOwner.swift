//
//  NavigationCameraOwner.swift
//  MetalModule
//
//  Created by Codex on 27.05.2026.
//

import Foundation
import simd

/// Owns navigation camera priority state and commits navigation camera transactions.
///
/// `NavigationCameraOwner` keeps route-specific camera ownership out of `CameraCoordinator` while
/// preserving ADR 0003's split: `NavigationCameraMode` computes camera transactions, this owner claims
/// or releases navigation camera priority, and `CameraState` remains the canonical commit target.
@MainActor
final class NavigationCameraOwner {
    private unowned let cameraState: CameraState
    private let navigationMode: NavigationCameraMode
    private(set) var routeID: UUID?

    init(cameraState: CameraState,
         navigationMode: NavigationCameraMode = NavigationCameraMode()) {
        self.cameraState = cameraState
        self.navigationMode = navigationMode
    }

    var isActive: Bool {
        routeID != nil
    }

    func begin(routeID: UUID) {
        self.routeID = routeID
    }

    func suspend(routeID: UUID?) {
        guard routeID == nil || self.routeID == routeID else { return }
        self.routeID = nil
    }

    func end(routeID: UUID?) {
        guard routeID == nil || self.routeID == routeID else { return }
        self.routeID = nil
    }

    func commitFollow(route: NavigationRoute,
                      currentPoint: SIMD3<Float>,
                      destinationPosition: SIMD3<Float>,
                      trailingOffset: SIMD3<Float>) {
        routeID = route.id
        cameraState.commit(navigationMode.makeNavigationFollowTransaction(currentPoint: currentPoint,
                                                                          destinationPosition: destinationPosition,
                                                                          trailingOffset: trailingOffset))
    }

    func commitArrival(route: NavigationRoute,
                       position: SIMD3<Float>,
                       target: SIMD3<Float>) {
        routeID = route.id
        cameraState.commit(navigationMode.makeNavigationArrivalTransaction(position: position,
                                                                          target: target))
    }

    func commitTransition(routeID: UUID,
                          frame: CameraTransition.Frame) {
        self.routeID = routeID
        cameraState.normalizeCameraOrientation()
        let cameraOffset = cameraState.cameraOrientation.act(SIMD3<Float>(0, 0, frame.distance))
        let cameraPosition = cameraOffset + frame.target
        let cameraUp = cameraState.cameraOrientation.act(SIMD3<Float>(0, 1, 0))

        cameraState.commit(CameraState.Transaction(cameraTarget: frame.target,
                                                   cameraPosition: cameraPosition,
                                                   cameraDistance: frame.distance,
                                                   cameraUp: cameraUp,
                                                   cameraOffset: cameraOffset))
    }

    func commitDestination(destinationPosition: SIMD3<Float>) {
        guard let transaction = navigationMode.makeDestinationTransaction(destinationPosition: destinationPosition,
                                                                         cameraPosition: cameraState.cameraPosition,
                                                                         cameraUp: cameraState.cameraUp) else {
            return
        }
        cameraState.commit(transaction)
    }
}
