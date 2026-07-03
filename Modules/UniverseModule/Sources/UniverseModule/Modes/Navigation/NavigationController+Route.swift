//
//  NavigationController+Route.swift
//  UniverseModule
//
//  Created by max on 25.05.2026.
//

extension NavigationController: UniverseNavigationControlling {
    func startNavigation(to name: String) {
        guard let snapshot = snapshotProvider.latestSnapshot,
              applyNavigation(named: name, snapshot: snapshot) else {
            pendingNavigationDestinationName = name
            return
        }

        pendingNavigationDestinationName = nil
    }

    func pauseNavigation() {
        navigationRouteCoordinator.pause()
    }

    func resumeNavigation() {
        navigationRouteCoordinator.resume()
    }

    func cancelNavigation() {
        navigationRouteCoordinator.cancel()
        isCameraAutoFramingEnabled = false
        pendingNavigationDestinationName = nil
    }

    func doneNavigation() {
        guard navigationRouteCoordinator.state == .completed else {
            cancelNavigation()
            return
        }

        let completedDestinationName = navigationSnapshot.destinationName
        navigationRouteCoordinator.cancel()
        isCameraAutoFramingEnabled = false
        pendingNavigationDestinationName = nil
        if let completedDestinationName {
            navigationDidComplete?(completedDestinationName)
        }
    }

    func applyNavigation(named name: String,
                         snapshot: UniverseSceneSnapshot) -> Bool {
        isCameraAutoFramingEnabled = true
        guard navigationRouteCoordinator.start(destinationName: name,
                                               planets: planets,
                                               snapshot: snapshot),
              navigationRouteCoordinator.route != nil else {
            isCameraAutoFramingEnabled = false
            return true
        }

        return true
    }
}
