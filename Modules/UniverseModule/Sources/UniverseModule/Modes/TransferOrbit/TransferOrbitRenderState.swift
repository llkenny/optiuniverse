//
//  TransferOrbitRenderState.swift
//  UniverseModule
//
//  Created by Codex on 28.05.2026.
//

struct TransferOrbitRenderState: Equatable {
    let transferOrbit: HohmannTransferOrbit?

    static let inactive = TransferOrbitRenderState(transferOrbit: nil)
}
