//
//  UniverseModuleResources+UniverseNavigationControlling.swift
//  UniverseModule
//
//  Created by max on 24.05.2026.
//

extension UniverseModuleResources: UniverseNavigationControlling {

    public var navigation: any UniverseNavigationControlling {
        self
    }

    public func startNavigation(from originName: String, via waypointName: String?, to destinationName: String) {
        transferOrbitController.clearTransferOrbit()
        navigationController.startNavigation(from: originName,
                                             via: waypointName,
                                             to: destinationName)
    }

    public func startMission(_ mission: MissionFlightPlan) {
        transferOrbitController.clearTransferOrbit()
        navigationController.startMission(mission)
    }

    public func cancelNavigation() {
        let wasStarshipFlight = navigationSnapshot.mission == .starshipFlight14
            && navigationController.isNavigationActive
        navigationController.cancelNavigation()
        if wasStarshipFlight {
            // Restore an Earth overview instead of returning the close-up distance to
            // the previously followed body (which may have been the Sun).
            cameraCoordinator.followNavigationDestination(named: "Earth", viewportSize: viewportSize)
        }
    }

    public func doneNavigation() {
        navigationController.doneNavigation()
    }
}
