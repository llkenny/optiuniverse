//
//  PlanetsRenderer.swift
//  MetalModule
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
    private(set) var pipelineState: MTLRenderPipelineState!
    private(set) var samplerState: MTLSamplerState!
    let opaqueDepthStencilState: MTLDepthStencilState
    let transparentDepthStencilState: MTLDepthStencilState

    var time: Float = 0
    var lastUpdateTime = CACurrentMediaTime()

    var planetScreenPositions: [String: SIMD2<Float>] = [:]

    /// World-space positions of planet centers, updated each frame.
    /// Keys are planet names, values are coordinates in the scene space.
    var planetWorldPositions: [String: SIMD3<Float>] = [:]

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
}
