//
//  MetalProvider.swift
//  OptiUniverse
//
//  Created by max on 17.04.2026.
//

import Metal

@Observable
public final class MetalProvider {

    let modelLoader: ModelLoader
    let device: MTLDevice

    var isReady: Bool = false

    init(modelLoader: ModelLoader) {
        self.modelLoader = modelLoader
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError()
        }
        self.device = device
    }

    func prepare() async {
        guard !isReady else { return }
        await modelLoader.loadMeshes(device: device)
        isReady = true
    }
}
