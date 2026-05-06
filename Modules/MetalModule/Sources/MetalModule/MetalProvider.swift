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

    public var transferOrbitSummary: TransferOrbitSummary?

    let modelLoader: ModelLoader
    let device: MTLDevice
    weak var renderer: MetalRenderer?

    private var isReady: Bool = false
    private var inFlightTask: Task<Void, Never>?

    public init(modelLoader: ModelLoader) {
        self.modelLoader = modelLoader
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError()
        }
        self.device = device
    }

    public func prepare() async {
        guard !isReady else { return }

        if let inFlightTask {
            await inFlightTask.value
            return
        }

        let task = Task {
            await modelLoader.loadMeshes(device: device)
        }

        self.inFlightTask = task
        await task.value
        isReady = true
        self.inFlightTask = nil
    }

    public func showTransferOrbit(to destinationName: String) {
        renderer?.showTransferOrbit(to: destinationName)
    }
}
