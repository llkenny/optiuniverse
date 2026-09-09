//
//  NavigationController+Route.swift
//  UniverseModule
//
//  Created by max on 25.05.2026.
//

extension NavigationController: UniverseNavigationControlling {
    func startNavigation(from originName: String, via waypointName: String?, to destinationName: String) {
        guard let snapshot = snapshotProvider.latestSnapshot,
              applyNavigation(from: originName,
                              via: waypointName,
                              to: destinationName,
                              snapshot: snapshot) else {
            pendingNavigationRequest = NavigationRequest(originName: originName,
                                                         waypointName: waypointName,
                                                         destinationName: destinationName)
            publishNavigationSnapshot(
                NavigationRouteSnapshot(routeID: nil,
                                        state: .preparing,
                                        originName: originName,
                                        waypointName: waypointName,
                                        destinationName: destinationName,
                                        progress: 0,
                                        elapsedTime: 0,
                                        remainingTime: 0,
                                        estimatedDuration: 0)
            )
            return
        }

        pendingNavigationRequest = nil
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
        pendingNavigationRequest = nil
    }

    func doneNavigation() {
        guard navigationRouteCoordinator.state == .completed else {
            cancelNavigation()
            return
        }

        let completedDestinationName = navigationSnapshot.destinationName
        navigationRouteCoordinator.cancel()
        isCameraAutoFramingEnabled = false
        pendingNavigationRequest = nil
        if let completedDestinationName {
            navigationDidComplete?(completedDestinationName)
        }
    }

    func applyNavigation(named name: String,
                         snapshot: UniverseSceneSnapshot) -> Bool {
        applyNavigation(from: "Earth",
                        via: nil,
                        to: name,
                        snapshot: snapshot)
    }

    func applyNavigation(from originName: String,
                         via waypointName: String? = nil,
                         to destinationName: String,
                         snapshot: UniverseSceneSnapshot) -> Bool {
        isCameraAutoFramingEnabled = true
        guard navigationRouteCoordinator.start(originName: originName,
                                               waypointName: waypointName,
                                               destinationName: destinationName,
                                               planets: planets,
                                               snapshot: snapshot),
              navigationRouteCoordinator.route != nil else {
            isCameraAutoFramingEnabled = false
            return true
        }

        return true
    }
}
