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
    let sceneOwnershipControls: MetalSceneOwnershipControls

    var time: Float = 0
    var lastUpdateTime = CACurrentMediaTime()

    var planetScreenPositions: [String: SIMD2<Float>] = [:]

    init(device: MTLDevice,
         sampleCount: Int,
         sceneOwnershipControls: MetalSceneOwnershipControls) {
        self.device = device
        self.sceneOwnershipControls = sceneOwnershipControls
        self.opaqueDepthStencilState = Self.makeDepthStencilState(device: device,
                                                                  writesDepth: true)
        self.transparentDepthStencilState = Self.makeDepthStencilState(device: device,
                                                                       writesDepth: false)

        pipelineState = makePipelineState(fragmentFunction: "fragment_main",
                                          sampleCount: sampleCount)
        samplerState = makeSamplerState()
    }
}
