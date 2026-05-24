//
//  MetalModuleResources+MetalModuleTransferOrbitControlling.swift
//  MetalModule
//
//  Created by max on 24.05.2026.
//

extension MetalModuleResources: MetalModuleTransferOrbitControlling {
    public func showTransferOrbit(to destinationName: String) {
        renderer?.showTransferOrbit(to: destinationName)
    }
}
