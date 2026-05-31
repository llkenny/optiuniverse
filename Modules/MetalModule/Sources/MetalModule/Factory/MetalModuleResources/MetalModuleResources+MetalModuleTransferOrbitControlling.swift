//
//  MetalModuleResources+MetalModuleTransferOrbitControlling.swift
//  MetalModule
//
//  Created by max on 24.05.2026.
//

extension MetalModuleResources: MetalModuleTransferOrbitControlling {

    public var transferOrbit: any MetalModuleTransferOrbitControlling {
        self
    }

    public func showTransferOrbit(to destinationName: String) {
        navigationController.cancelNavigation(followDestination: false)
        transferOrbitController.showTransferOrbit(to: destinationName)
    }

    public func clearTransferOrbit() {
        transferOrbitController.cancelTransferOrbit()
    }
}
