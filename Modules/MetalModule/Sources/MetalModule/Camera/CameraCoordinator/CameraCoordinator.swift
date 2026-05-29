//
//  CameraCoordinator.swift
//  MetalModule
//
//  Created by max on 22.05.2026.
//

import CoreFoundation
import CoreGraphics
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
    private unowned let snapshotProvider: SnapshotProvider

    private let zoomMode: ZoomCameraMode
    private let orbitMode: OrbitCameraMode
    private let trajectoryMode: TrajectoryCameraMode
    let followCameraOwner: FollowCameraOwner
    let navigationCameraOwner: NavigationCameraOwner
    let transferPreviewCameraOwner: TransferPreviewCameraOwner

    private var displayLink: CADisplayLink?

    init(cameraState: CameraState,
         snapshotProvider: SnapshotProvider) {
        self.cameraState = cameraState
        self.snapshotProvider = snapshotProvider
        zoomMode = .init(cameraState: cameraState)
        orbitMode = .init(cameraState: cameraState)
        trajectoryMode = .init(cameraState: cameraState)
        followCameraOwner = .init(cameraState: cameraState,
                                  snapshotProvider: snapshotProvider)
        navigationCameraOwner = .init(cameraState: cameraState)
        transferPreviewCameraOwner = .init(cameraState: cameraState)
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

    func activate() {
        startLoop()
    }

    func deactivate() {
        stopLoop()
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

    func followPlanet(named name: String,
                      viewportSize: CGSize) {
        followCameraOwner.followPlanet(named: name,
                                       viewportSize: viewportSize)
        refreshCamera()
    }

    func followNavigationDestination(named name: String,
                                     viewportSize: CGSize) {
        followCameraOwner.followPlanet(named: name,
                                       viewportSize: viewportSize)
        refreshCamera()
    }

    func beginManualCameraControl() {
        followCameraOwner.beginManualCameraControl()
    }

    func updateFollowCamera(snapshot: PreparedRenderSnapshot?,
                            delta: Float,
                            viewportSize: CGSize,
                            isSuppressed: Bool) {
        followCameraOwner.update(snapshot: snapshot,
                                 delta: delta,
                                 viewportSize: viewportSize,
                                 isSuppressed: isSuppressed)
        if !isSuppressed {
            refreshCamera(snapshot: snapshot)
        }
    }

    func followProjectionParameters(snapshot: PreparedRenderSnapshot?,
                                    baseProjection: CameraProjectionParameters) -> CameraProjectionParameters {
        followCameraOwner.projectionParameters(snapshot: snapshot,
                                               baseProjection: baseProjection)
    }

    func refreshCamera(snapshot: PreparedRenderSnapshot? = nil) {
        let snapshot = snapshot ?? snapshotProvider.latestSnapshot
        cameraState.refreshDerivedCameraValues(
            minDistance: followCameraOwner.minimumAllowedCameraDistance(snapshot: snapshot)
        )
    }

    private func update(delta: Float) {
        zoomMode.update(delta: delta)
        orbitMode.update(delta: delta)

        if !isNavigationCameraActive {
            refreshCamera()
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
