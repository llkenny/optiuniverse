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

    public func pauseNavigation() {
        navigationController.pauseNavigation()
    }

    public func resumeNavigation() {
        navigationController.resumeNavigation()
    }

    public func cancelNavigation() {
        navigationController.cancelNavigation()
    }

    public func doneNavigation() {
        navigationController.doneNavigation()
    }
}
