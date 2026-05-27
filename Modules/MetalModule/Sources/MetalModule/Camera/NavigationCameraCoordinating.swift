//
//  NavigationCameraCoordinating.swift
//  MetalModule
//
//  Created by Codex on 27.05.2026.
//

import Foundation
import simd

/// Navigation-facing camera coordination surface.
///
/// This protocol keeps route navigation coupled to the camera ownership contract instead of the concrete
/// `CameraCoordinator` type. Navigation can claim/release camera ownership and commit navigation camera
/// transactions, while the coordinator remains free to own priority and route those commits internally.
@MainActor
protocol NavigationCameraCoordinating: AnyObject {
    var currentCameraTransitionFrame: CameraTransition.Frame { get }
    var cameraFollowTransitionDuration: Float { get }
    var cameraPosition: SIMD3<Float> { get }
    var cameraTarget: SIMD3<Float> { get }
    var cameraDistance: Float { get }

    func claimNavigationCameraControl(routeID: UUID)
    func suspendNavigationFollow(routeID: UUID?)
    func endNavigationCameraControl(routeID: UUID?)
    func commitNavigationFollow(route: NavigationRoute,
                                currentPoint: SIMD3<Float>,
                                destinationPosition: SIMD3<Float>,
                                trailingOffset: SIMD3<Float>)
    func commitNavigationArrival(route: NavigationRoute,
                                 position: SIMD3<Float>,
                                 target: SIMD3<Float>)
    func commitNavigationTransition(routeID: UUID,
                                    frame: CameraTransition.Frame)
    func commitNavigationDestination(destinationPosition: SIMD3<Float>)
}
