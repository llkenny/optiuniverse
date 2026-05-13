//
//  OrbitRenderHandler.swift
//  MetalModule
//
//  Created by max on 13.05.2026.
//

import Observation

@MainActor
@Observable
public final class OrbitRenderHandler: OrbitRenderHandlerProtocol {

    public var transferOrbitSummary: TransferOrbitSummary?
    weak var renderer: MetalRenderer?

    public init() {
    }
}

extension OrbitRenderHandler: OrbitRenderHandlerEventsProtocol {
    public func showTransferOrbit(to destinationName: String) {
        renderer?.showTransferOrbit(to: destinationName)
    }
}

@MainActor
protocol OrbitRenderHandlerProtocol: AnyObject {
    var transferOrbitSummary: TransferOrbitSummary? { get set }
}

@MainActor
public protocol OrbitRenderHandlerEventsProtocol: AnyObject {
    var transferOrbitSummary: TransferOrbitSummary? { get }

    func showTransferOrbit(to destinationName: String)
}
