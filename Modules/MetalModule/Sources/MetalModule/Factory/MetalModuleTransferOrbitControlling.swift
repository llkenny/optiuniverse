//
//  MetalModuleTransferOrbitControlling.swift
//  MetalModule
//
//  Created by max on 24.05.2026.
//

@MainActor
public protocol MetalModuleTransferOrbitControlling: AnyObject {
    func showTransferOrbit(to destinationName: String)
    func clearTransferOrbit()
}
