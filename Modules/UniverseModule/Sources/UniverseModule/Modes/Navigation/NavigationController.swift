//
//  NavigationController.swift
//  UniverseModule
//
//  Created by max on 25.05.2026.
//

import Foundation

/// Main controller for time-dependent route navigation.
///
/// `NavigationController` is the module-facing owner of route navigation. It translates public
/// navigation commands into route playback and render-state publishing.
/// The controller is necessary because route navigation is a long-lived mode: it spans multiple render
/// frames and can be paused or cancelled.
///
/// Ownership:
/// - Owns `NavigationRouteCoordinator`.
/// - Does not own canonical camera variables or camera behavior.
/// - Reads scene data through `SnapshotProvider` but does not own snapshot production.
/// - Stores and publishes public navigation state through `UniverseNavigationControlling`.
@MainActor
final class NavigationController {
    let routeBuilder: RouteBuilding
    let routePlayback: RoutePlayback
    unowned let snapshotProvider: SnapshotProvider
    let planets: [Planet]
    var navigationSnapshotDidChange: ((NavigationRouteSnapshot) -> Void)?
    lazy var navigationRouteCoordinator = NavigationRouteCoordinator(
        routeBuilder: routeBuilder,
        playback: routePlayback,
        snapshotPublisher: { [weak self] snapshot in
            self?.publishNavigationSnapshot(snapshot)
        }
    )

    var pendingNavigationDestinationName: String?

    private(set) var navigationSnapshot: NavigationRouteSnapshot = .idle {
        didSet {
            navigationSnapshotDidChange?(navigationSnapshot)
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

    init(snapshotProvider: SnapshotProvider,
         planets: [Planet],
         routeBuilder: RouteBuilding = RoutePathBuilder(),
         routePlayback: RoutePlayback = RoutePlaybackController()) {
        self.snapshotProvider = snapshotProvider
        self.planets = planets
        self.routeBuilder = routeBuilder
        self.routePlayback = routePlayback
    }

    func update(snapshot: UniverseSceneSnapshot?,
                delta: Float) {
        if let snapshot,
           let name = pendingNavigationDestinationName,
           applyNavigation(named: name, snapshot: snapshot) {
            pendingNavigationDestinationName = nil
        }

        navigationRouteCoordinator.update()

        if let snapshot {
            refreshActiveRoute(snapshot: snapshot)
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
