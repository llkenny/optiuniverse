//
//  NavigationController.swift
//  MetalModule
//
//  Created by max on 25.05.2026.
//

import CoreGraphics
import Foundation
import simd

/// Main controller for time-dependent route navigation.
///
/// `NavigationController` is the module-facing owner of route navigation. It translates public
/// navigation commands into route playback, render-state publishing, and navigation camera requests.
/// The controller is necessary because route navigation is a long-lived mode: it spans multiple render
/// frames, can be paused or cancelled, and needs to coordinate route progress with camera ownership.
///
/// Ownership:
/// - Owns `NavigationRouteCoordinator` and all route-specific pending/arrival camera state.
/// - Does not own canonical camera variables; it asks `NavigationCameraCoordinating` to claim or release
///   navigation camera ownership and to commit camera transactions.
/// - Reads scene data through `SnapshotProvider` but does not own snapshot production.
/// - Stores and publishes public navigation state through `MetalModuleNavigationControlling`.
/// - Uses `followPlanet` only as a completion/cancellation handoff back to legacy non-navigation follow
///   behavior that still lives outside the route navigation mode.
@MainActor
final class NavigationController {
    let routeBuilder: RouteBuilding
    let routePlayback: RoutePlayback
    unowned let snapshotProvider: SnapshotProvider
    unowned let cameraCoordinator: any NavigationCameraCoordinating
    let planets: [Planet]
    let viewportSize: () -> CGSize
    lazy var navigationRouteCoordinator = NavigationRouteCoordinator(
        routeBuilder: routeBuilder,
        playback: routePlayback,
        snapshotPublisher: { [weak self] snapshot in
            self?.publishNavigationSnapshot(snapshot)
        }
    )

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

    private(set) var navigationSnapshot: NavigationRouteSnapshot = .idle {
        didSet {
            if navigationSnapshot.state == .completed {
                scheduleDoneNavigation()
            } else {
                pendingDoneNavigationTask?.cancel()
            }
        }
    }
    private var pendingDoneNavigationTask: Task<Void, Never>?

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

    init(snapshotProvider: SnapshotProvider,
         cameraCoordinator: any NavigationCameraCoordinating,
         planets: [Planet],
         viewportSize: @escaping () -> CGSize,
         routeBuilder: RouteBuilding = RoutePathBuilder(),
         routePlayback: RoutePlayback = RoutePlaybackController()) {
        self.snapshotProvider = snapshotProvider
        self.cameraCoordinator = cameraCoordinator
        self.planets = planets
        self.viewportSize = viewportSize
        self.routeBuilder = routeBuilder
        self.routePlayback = routePlayback
    }

    func update(snapshot: PreparedRenderSnapshot?,
                delta: Float) {
        if let snapshot,
           let name = pendingNavigationDestinationName,
           applyNavigation(named: name, snapshot: snapshot) {
            pendingNavigationDestinationName = nil
        }

        navigationRouteCoordinator.update()

        if let snapshot {
            refreshActiveRoute(snapshot: snapshot)
            updateNavigationCamera(snapshot: snapshot,
                                   delta: delta)
        }
    }

    func beginManualCameraControl() {
        guard navigationRouteCoordinator.isNavigationActive else {
            return
        }

        cameraCoordinator.suspendNavigationFollow(routeID: navigationRouteCoordinator.activeRouteForRendering?.id)
        cameraTransition = nil

        if navigationCameraFollowEnabled {
            navigationCameraFollowEnabled = false
        }
    }

    private func publishNavigationSnapshot(_ snapshot: NavigationRouteSnapshot) {
        navigationSnapshot = snapshot
    }

    private func scheduleDoneNavigation() {
        let routeID = navigationSnapshot.routeID

        pendingDoneNavigationTask?.cancel()
        pendingDoneNavigationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(1_100))
            } catch {
                return
            }

            await MainActor.run {
                guard let self,
                      self.navigationSnapshot.state == .completed,
                      self.navigationSnapshot.routeID == routeID else {
                    return
                }

                self.doneNavigation()
            }
        }
    }
}
