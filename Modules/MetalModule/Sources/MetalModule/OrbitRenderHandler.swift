//
//  OrbitRenderHandler.swift
//  MetalModule
//
//  Created by max on 13.05.2026.
//

@MainActor
public final class OrbitRenderHandler {
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
public protocol OrbitRenderHandlerEventsProtocol: AnyObject {
    func showTransferOrbit(to destinationName: String)
}
