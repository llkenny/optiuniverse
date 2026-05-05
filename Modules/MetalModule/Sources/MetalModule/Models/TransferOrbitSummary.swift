//
//  TransferOrbitSummary.swift
//  MetalModule
//
//  Created by Codex on 05.05.2026.
//

public struct TransferOrbitSummary: Equatable, Sendable {
    public let destinationName: String
    public let earthOrbitRadiusAU: Float
    public let destinationOrbitRadiusAU: Float
    public let semiMajorAxisAU: Float
}
