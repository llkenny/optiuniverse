//
//  UniverseModuleResources+UniverseTransferOrbitControlling.swift
//  UniverseModule
//
//  Created by max on 24.05.2026.
//

extension UniverseModuleResources: UniverseTransferOrbitControlling {

    public var transferOrbit: any UniverseTransferOrbitControlling {
        self
    }

    public func showTransferOrbit(to destinationName: String) {
        navigationController.cancelNavigation()
        transferOrbitController.showTransferOrbit(to: destinationName)
    }

    public func clearTransferOrbit() {
        transferOrbitController.cancelTransferOrbit()
    }
}
