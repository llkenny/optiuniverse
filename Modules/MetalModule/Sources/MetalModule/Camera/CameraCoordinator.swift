//
//  CameraCoordinator.swift
//  MetalModule
//
//  Created by max on 22.05.2026.
//

import CoreFoundation
import Foundation
import QuartzCore
import simd

/*
 Owns camera mode priority, ownership, cancellation, and ticking.
 It decides which mode receives a command or time update,
 whether a command cancels or suspends another mode, and which transactional camera mutation is committed.
 Camera mode priority becomes explicit.
 Conflicts such as manual control cancelling follow, navigation owning the camera while active,
 or trajectory pan only applying in trajectory mode should be resolved by the camera mode layer or a camera coordinator,
 not by renderer branches.

 The coordinator must stay focused on routing and ownership.
 It should not perform matrix math or directly encode mode-specific camera behavior.
 Mode-specific transformations belong in the modes, and matrix derivation belongs in the snapshot provider.

 The implementation should avoid letting every mode freely mutate state in incompatible ways.
 Modes should emit camera commands or transactional mutations through `CameraCoordinator`
 so ownership and cancellation rules remain visible.
 */
@MainActor
final class CameraCoordinator {

    // MARK: Constants
    private let orbitSpeed: Float = 0.01

    private let cameraState: CameraState

    private let zoomMode: ZoomCameraMode
    private let orbitMode: OrbitCameraMode
    private let trajectoryMode: TrajectoryCameraMode
    private let navigationMode: NavigationCameraMode

    private var displayLink: CADisplayLink?
    private(set) var navigationCameraOwnerRouteID: UUID?

    weak var renderer: MetalRenderer?

    init(cameraState: CameraState) {
        self.cameraState = cameraState
        zoomMode = .init(cameraState: cameraState)
        orbitMode = .init(cameraState: cameraState)
        trajectoryMode = .init(cameraState: cameraState)
        navigationMode = .init()
    }

    var isNavigationCameraActive: Bool {
        navigationCameraOwnerRouteID != nil
    }

    var cameraRevision: Int {
        cameraState.revision
    }

    var currentCameraTransitionFrame: CameraTransition.Frame {
        cameraState.currentCameraTransitionFrame
    }

    var cameraFollowTransitionDuration: Float {
        cameraState.cameraFollowTransitionDuration
    }

    var cameraPosition: SIMD3<Float> {
        cameraState.cameraPosition
    }

    var cameraTarget: SIMD3<Float> {
        cameraState.cameraTarget
    }

    var cameraDistance: Float {
        cameraState.cameraDistance
    }

    var cameraUp: SIMD3<Float> {
        cameraState.cameraUp
    }

    func activate(renderer: MetalRenderer) {
        self.renderer = renderer
        startLoop()
    }

    func deactivate(renderer: MetalRenderer?) {
        if self.renderer === renderer || renderer == nil {
            self.renderer = nil
            stopLoop()
        }
    }

    func makeTranslation(with value: CGPoint) {
        trajectoryMode.apply(translation: value)
    }

    func makeRotation(with value: CGPoint, velocity: CGPoint) {
        orbitMode.apply(horizontal: Float(value.x) * orbitSpeed,
                        vertical: -Float(value.y) * orbitSpeed)
        orbitMode.addInertia(velocity: velocity)
    }

    func makeScale(with value: Float, velocity: CGFloat) {
        zoomMode.apply(value: value)
        zoomMode.addInertia(velocity: velocity)
    }

    func beginNavigationCameraControl(routeID: UUID) {
        navigationCameraOwnerRouteID = routeID
    }

    func suspendNavigationFollow(routeID: UUID?) {
        guard routeID == nil || navigationCameraOwnerRouteID == routeID else { return }
        navigationCameraOwnerRouteID = nil
    }

    func endNavigationCameraControl(routeID: UUID?) {
        guard routeID == nil || navigationCameraOwnerRouteID == routeID else { return }
        navigationCameraOwnerRouteID = nil
    }

    func commitNavigationFollow(route: NavigationRoute,
                                currentPoint: SIMD3<Float>,
                                destinationPosition: SIMD3<Float>,
                                trailingOffset: SIMD3<Float>) {
        navigationCameraOwnerRouteID = route.id
        cameraState.commit(navigationMode.makeNavigationFollowTransaction(currentPoint: currentPoint,
                                                                          destinationPosition: destinationPosition,
                                                                          trailingOffset: trailingOffset))
    }

    func commitNavigationArrival(route: NavigationRoute,
                                 position: SIMD3<Float>,
                                 target: SIMD3<Float>) {
        navigationCameraOwnerRouteID = route.id
        cameraState.commit(navigationMode.makeNavigationArrivalTransaction(position: position,
                                                                          target: target))
    }

    func commitNavigationTransition(routeID: UUID,
                                    frame: CameraTransition.Frame) {
        navigationCameraOwnerRouteID = routeID
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

    func commitNavigationDestination(destinationPosition: SIMD3<Float>) {
        guard let transaction = navigationMode.makeDestinationTransaction(destinationPosition: destinationPosition,
                                                                         cameraPosition: cameraState.cameraPosition,
                                                                         cameraUp: cameraState.cameraUp) else {
            return
        }
        cameraState.commit(transaction)
    }

    private func update(delta: Float) {
        zoomMode.update(delta: delta)
        orbitMode.update(delta: delta)

        if !isNavigationCameraActive {
            renderer?.updateCamera()
        }
    }

    // MARK: Update loop

    private func startLoop() {
        guard displayLink == nil else { return }

        displayLink = CADisplayLink(target: self, selector: #selector(step(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopLoop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        let delta = Float(link.duration)
        update(delta: delta)
    }
}
