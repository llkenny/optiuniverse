//
//  UniverseTransferOrbitControlling.swift
//  UniverseModule
//
//  Created by max on 24.05.2026.
//

@MainActor
public protocol UniverseTransferOrbitControlling: AnyObject {
    var transferPreviewSnapshot: TransferPreviewSnapshot { get }
    func showTransferOrbit(to destinationName: String)
    func clearTransferOrbit()
}

public extension UniverseTransferOrbitControlling {
    var transferPreviewSnapshot: TransferPreviewSnapshot { .inactive }
}
