//
//  FollowCameraOwner.swift
//  MetalModule
//
//  Created by Codex on 29.05.2026.
//

import CoreGraphics

/// Owns lifecycle state for the current planet-follow camera mode.
///
/// `FollowCameraOwner` is the stateful companion to `FollowCameraMode`. It retains the current
/// followed planet, retries follow requests that arrive before a prepared snapshot is available,
/// and advances follow transitions over render frames.
///
/// Ownership rules:
/// - user follow commands are routed here by `MetalModuleResources` after clearing/cancelling
///   higher-level modes such as transfer preview and route navigation
/// - navigation/transfer fallback handoffs can reuse the same follow path without recursively
///   cancelling navigation
/// - manual control clears pending/active follow transitions, but keeps the selected follow target
///   so steady follow can resume when the camera is not suppressed
@MainActor
final class FollowCameraOwner {
    private unowned let cameraState: CameraState
    private unowned let snapshotProvider: SnapshotProvider
    private let followMode: FollowCameraMode

    private(set) var followingPlanetName: String? = "Sun"
    private var pendingFollowPlanetName: String?
    private var cameraTransition: CameraTransition?

    init(cameraState: CameraState,
         snapshotProvider: SnapshotProvider,
         followMode: FollowCameraMode = FollowCameraMode()) {
        self.cameraState = cameraState
        self.snapshotProvider = snapshotProvider
        self.followMode = followMode
    }

    func followPlanet(named name: String,
                      viewportSize: CGSize) {
        followingPlanetName = name

        guard let snapshot = snapshotProvider.latestSnapshot,
              startFollowAnimation(named: name,
                                   snapshot: snapshot,
                                   viewportSize: viewportSize) else {
            pendingFollowPlanetName = name
            cameraTransition = nil
            return
        }

        pendingFollowPlanetName = nil
    }

    func beginManualCameraControl() {
        pendingFollowPlanetName = nil
        cameraTransition = nil
    }

    /// Advances pending follow resolution, active transitions, or steady target tracking.
    ///
    /// Suppression is used while navigation or transfer preview owns the camera. In that state, the
    /// owner keeps follow intent but avoids committing camera transactions.
    func update(snapshot: PreparedRenderSnapshot?,
                delta: Float,
                viewportSize: CGSize,
                isSuppressed: Bool) {
        guard let snapshot else { return }

        if !isSuppressed,
           let name = pendingFollowPlanetName,
           startFollowAnimation(named: name,
                                snapshot: snapshot,
                                viewportSize: viewportSize) {
            pendingFollowPlanetName = nil
        }

        guard !isSuppressed else { return }

        if cameraTransition != nil {
            updateCameraTransition(snapshot: snapshot,
                                   delta: delta,
                                   viewportSize: viewportSize)
        } else if let name = followingPlanetName,
                  let transaction = followMode.makeSteadyFollowTransaction(named: name,
                                                                           snapshot: snapshot) {
            cameraState.commit(transaction)
        }
    }

    func minimumAllowedCameraDistance(snapshot: PreparedRenderSnapshot?) -> Float {
        followMode.minimumDistance(followingPlanetName: followingPlanetName,
                                   snapshot: snapshot,
                                   baseMinimumDistance: cameraState.minDistance)
    }

    func projectionParameters(snapshot: PreparedRenderSnapshot?,
                              baseProjection: CameraProjectionParameters) -> CameraProjectionParameters {
        followMode.projectionParameters(followingPlanetName: followingPlanetName,
                                        snapshot: snapshot,
                                        cameraDistance: cameraState.cameraDistance,
                                        baseProjection: baseProjection)
    }

    private func startFollowAnimation(named name: String,
                                      snapshot: PreparedRenderSnapshot,
                                      viewportSize: CGSize) -> Bool {
        guard followMode.makeTransitionFrame(named: name,
                                             snapshot: snapshot,
                                             currentDistance: cameraState.cameraDistance,
                                             viewportSize: viewportSize) != nil else {
            return false
        }

        cameraTransition = CameraTransition(
            start: cameraState.currentCameraTransitionFrame,
            destination: .planet(name: name),
            duration: cameraState.cameraFollowTransitionDuration
        )
        return true
    }

    private func updateCameraTransition(snapshot: PreparedRenderSnapshot,
                                        delta: Float,
                                        viewportSize: CGSize) {
        guard var transition = cameraTransition else { return }
        guard let frame = transition.advance(delta: delta, resolveDestination: { [weak self] destination in
            guard let self else { return nil }
            return self.resolveCameraTransitionDestination(destination,
                                                           snapshot: snapshot,
                                                           viewportSize: viewportSize)
        }) else {
            return
        }

        cameraTransition = transition.isComplete ? nil : transition
        cameraState.commit(followMode.makeTransitionTransaction(
            frame: frame,
            cameraOrientation: cameraState.cameraOrientation
        ))
    }

    private func resolveCameraTransitionDestination(_ destination: CameraTransition.Destination,
                                                    snapshot: PreparedRenderSnapshot,
                                                    viewportSize: CGSize)
    -> CameraTransition.Frame? {
        switch destination {
        case .planet(let name):
            return followMode.makeTransitionFrame(named: name,
                                                  snapshot: snapshot,
                                                  currentDistance: cameraState.cameraDistance,
                                                  viewportSize: viewportSize)
        case .fixed(let target, let distance):
            return CameraTransition.Frame(target: target,
                                          distance: distance)
        }
    }
}
