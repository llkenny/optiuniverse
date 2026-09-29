//
//  NavigationController+Route.swift
//  UniverseModule
//
//  Created by max on 25.05.2026.
//

extension NavigationController: UniverseNavigationControlling {
    func startNavigation(from originName: String, via waypointName: String?, to destinationName: String) {
        startRequest(NavigationRequest(originName: originName, waypointName: waypointName,
                                       destinationName: destinationName))
    }

    func startMission(_ mission: MissionFlightPlan) {
        startRequest(NavigationRequest(originName: "Earth",
                                       waypointName: mission == .artemisII ? "Moon" : nil,
                                       destinationName: "Earth", mission: mission))
    }

    private func startRequest(_ request: NavigationRequest) {
        let originName = request.originName
        let waypointName = request.waypointName
        let destinationName = request.destinationName
        // A pending start must replace any previous playback immediately.
        if snapshotProvider.latestSnapshot == nil { navigationRouteCoordinator.cancel() }
        guard let snapshot = snapshotProvider.latestSnapshot,
              applyNavigation(from: originName,
                              via: waypointName,
                              to: destinationName,
                              snapshot: snapshot,
                              mission: request.mission) else {
            pendingNavigationRequest = request
            publishNavigationSnapshot(
                NavigationRouteSnapshot(routeID: nil,
                                        state: .preparing,
                                        originName: originName,
                                        waypointName: waypointName,
                                        destinationName: destinationName,
                                        progress: 0,
                                        elapsedTime: 0,
                                        remainingTime: 0,
                                        estimatedDuration: 0,
                                        mission: request.mission)
            )
            return
        }

        pendingNavigationRequest = nil
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
        let completedMission = navigationSnapshot.mission
        navigationRouteCoordinator.cancel()
        isCameraAutoFramingEnabled = false
        pendingNavigationRequest = nil
        if let completedDestinationName {
            navigationDidComplete?(completedDestinationName, completedMission)
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
                         snapshot: UniverseSceneSnapshot,
                         mission: MissionFlightPlan? = nil) -> Bool {
        isCameraAutoFramingEnabled = true
        guard navigationRouteCoordinator.start(originName: originName,
                                               waypointName: waypointName,
                                               destinationName: destinationName,
                                               planets: planets,
                                               snapshot: snapshot,
                                               mission: mission),
              navigationRouteCoordinator.route != nil else {
            isCameraAutoFramingEnabled = false
            return true
        }

        return true
    }
}
