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
        let wasEarthMission = (navigationSnapshot.mission == .starshipFlight14 || navigationSnapshot.mission == .crew13)
            && navigationController.isNavigationActive
        navigationController.cancelNavigation()
        if wasEarthMission {
            // Restore an Earth overview instead of returning the close-up distance to
            // the previously followed body (which may have been the Sun).
            cameraCoordinator.followNavigationDestination(named: "Earth", viewportSize: viewportSize)
        }
    }

    public func doneNavigation() {
        navigationController.doneNavigation()
    }
}
