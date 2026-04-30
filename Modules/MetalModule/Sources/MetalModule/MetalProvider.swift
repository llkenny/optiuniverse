//
//  MetalProvider.swift
//  OptiUniverse
//
//  Created by max on 17.04.2026.
//

import Metal

@Observable
@MainActor
public final class MetalProvider {

    let modelLoader: ModelLoader
    let device: MTLDevice

    public var isReady: Bool = false

    // TODO: Make MetalProviderProtocol
    public init(modelLoader: ModelLoader) {
        self.modelLoader = modelLoader
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError()
        }
        self.device = device
    }

    public func prepare() async {
        guard !isReady else { return }
        await modelLoader.loadMeshes(device: device)
        isReady = true
    }
}
