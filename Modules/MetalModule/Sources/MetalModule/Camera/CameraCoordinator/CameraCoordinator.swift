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

/// Routes camera commands to the active camera mode owners.
///
/// `CameraCoordinator` is the camera-layer entry point used by UI gestures, navigation, transfer
/// preview, and the renderer frame loop. It owns mode priority and lifecycle routing, then delegates
/// mode-specific math to owners/modes that commit `CameraState.Transaction` values.
///
/// ADR 0003 boundary:
/// - UI and feature controllers call this coordinator instead of mutating renderer camera fields.
/// - Follow, navigation, transfer preview, orbit, zoom, and trajectory behavior stay in camera modes.
/// - `SnapshotProvider` derives render-ready matrices from committed `CameraState`; the coordinator
///   only refreshes derived state needed by the current mode before snapshots are requested.
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

    /// Advances the follow camera when no higher-priority mode currently owns the camera.
    ///
    /// `isSuppressed` is true while navigation controls the camera or transfer preview is active.
    /// Pending follow requests are preserved while suppressed and resolve on a later frame.
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

    /// Rebuilds derived camera values after mode transactions or gesture inertia.
    ///
    /// This replaces the old renderer-owned `updateCamera()` path while keeping matrix derivation
    /// centralized in `CameraState`/`SnapshotProvider`.
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
