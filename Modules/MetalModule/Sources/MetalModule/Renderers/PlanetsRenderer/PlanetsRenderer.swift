//
//  PlanetsRenderer.swift
//  OptiUniverse
//
//  Created by max on 05.08.2025.
//

import MetalKit

final class PlanetsRenderer {
    enum RenderPass {
        case opaque
        case transparent
    }

    let device: MTLDevice
    var pipelineState: MTLRenderPipelineState!
    private(set) var samplerState: MTLSamplerState!
    private let opaqueDepthStencilState: MTLDepthStencilState
    private let transparentDepthStencilState: MTLDepthStencilState

    private var time: Float = 0
    var lastUpdateTime = CACurrentMediaTime()

    /// Screen-space positions of planet centers, updated each frame.
    /// Keys are planet names, values are pixel coordinates in the viewport.
    var planetScreenPositions: [String: SIMD2<Float>] = [:]

    /// World-space positions of planet centers, updated each frame.
    /// Keys are planet names, values are coordinates in the scene space.
    var planetWorldPositions: [String: SIMD3<Float>] = [:]

    /// Current simulation time used for planet animations.
    var currentTime: Float { time }

    init(device: MTLDevice, sampleCount: Int) {
        self.device = device
        self.opaqueDepthStencilState = Self.makeDepthStencilState(device: device,
                                                                  writesDepth: true)
        self.transparentDepthStencilState = Self.makeDepthStencilState(device: device,
                                                                       writesDepth: false)

        pipelineState = makePipelineState(fragmentFunction: "fragment_main",
                                          sampleCount: sampleCount)
        samplerState = makeSamplerState()
    }

    /// Advances the internal time accumulator and returns the time delta.
    /// Should be called once per frame before rendering so other systems can
    /// use the updated time (e.g. camera following).
    func advanceTime() -> Float {
        let currentTime = CACurrentMediaTime()
        let delta = Float(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        time += delta
        return delta
    }

    func renderPlanets(configuration: PlanetRenderConfiguration) {
        planetScreenPositions.removeAll()
        planetWorldPositions.removeAll()

        guard let snapshot = configuration.snapshot else { return }

        configuration.renderEncoder.setRenderPipelineState(pipelineState)
        configuration.renderEncoder.setDepthStencilState(opaqueDepthStencilState)
        for planet in snapshot.planets {
            renderPlanet(planet,
                         renderPass: .opaque,
                         configuration: configuration)
        }

        let cameraWorldPosition = configuration.sceneOrigin + configuration.cameraPosition
        let transparentPlanets = snapshot.planets
            .filter { planet in
                hasTransparentSubmesh(in: planet)
            }
            .sorted {
                simd_distance_squared($0.worldPosition, cameraWorldPosition) >
                simd_distance_squared($1.worldPosition, cameraWorldPosition)
            }

        configuration.renderEncoder.setDepthStencilState(transparentDepthStencilState)
        for planet in transparentPlanets {
            renderPlanet(planet,
                         renderPass: .transparent,
                         configuration: configuration)
        }
    }
}
