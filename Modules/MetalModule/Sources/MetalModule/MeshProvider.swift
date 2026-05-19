//
//  MeshProvider.swift
//  OptiUniverse
//
//  Created by max on 17.04.2026.
//

import Metal

/// Mesh provider (previously named MetalProvider).
/// Stores necessary dependencies and handles loading deduplication.
/// Model loading logic is in ModelLoader.
@MainActor
public final class MeshProvider {

    let modelLoader: ModelLoader
    let device: MTLDevice

    private var isReady: Bool = false
    private var inFlightTask: Task<Void, Never>?

    public init() {
        self.modelLoader = ModelLoader(resourceName: "high_resolution_solar_system")
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
}
