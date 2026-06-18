//
//  UniverseTransferOrbitControlling.swift
//  UniverseModule
//
//  Created by max on 24.05.2026.
//

@MainActor
public protocol UniverseTransferOrbitControlling: AnyObject {
    func showTransferOrbit(to destinationName: String)
    func clearTransferOrbit()
}
