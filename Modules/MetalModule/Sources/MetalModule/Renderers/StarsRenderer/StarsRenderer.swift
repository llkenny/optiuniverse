//
//  StarsRenderer.swift
//  OptiUniverse
//
//  Created by Codex on 04.05.2026.
//

import Metal
import simd

final class StarsRenderer {
    private static let colorPixelFormat: MTLPixelFormat = .rgba16Float
    private static let depthPixelFormat: MTLPixelFormat = .depth32Float

    private let pipelineState: MTLRenderPipelineState
    private let depthStencilState: MTLDepthStencilState
    private let starBuffer: MTLBuffer?
    private let starCount: Int

    init(device: MTLDevice,
         sampleCount: Int,
         configuration: StarFieldConfiguration = StarFieldConfiguration()) {
        let stars = StarFieldGenerator.makeStars(configuration: configuration)
        starCount = stars.count
        if stars.isEmpty {
            starBuffer = nil
        } else {
            starBuffer = device.makeBuffer(bytes: stars,
                                           length: MemoryLayout<StarVertex>.stride * stars.count,
                                           options: .storageModeShared)
        }
        pipelineState = Self.makePipelineState(device: device, sampleCount: sampleCount)
        depthStencilState = Self.makeDepthStencilState(device: device)
    }

    func render(renderEncoder: MTLRenderCommandEncoder,
                viewMatrix: float4x4,
                projectionMatrix: float4x4,
                sceneOrigin: SIMD3<Float>) {
        guard let starBuffer, starCount > 0 else { return }

        var uniforms = StarUniforms(
            viewMatrix: viewMatrix,
            projectionMatrix: projectionMatrix,
            sceneOrigin: sceneOrigin
        )
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setVertexBuffer(starBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&uniforms,
                                     length: MemoryLayout<StarUniforms>.stride,
                                     index: 1)
        renderEncoder.drawPrimitives(type: .point,
                                     vertexStart: 0,
                                     vertexCount: starCount)
    }

    private static func makePipelineState(device: MTLDevice,
                                          sampleCount: Int) -> MTLRenderPipelineState {
        let library: MTLLibrary
        do {
            library = try device.makeDefaultLibrary(bundle: .module)
        } catch {
            fatalError("Failed to load Metal shader library from MetalModule bundle: \(error)")
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.rasterSampleCount = sampleCount
        descriptor.colorAttachments[0].pixelFormat = Self.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        descriptor.depthAttachmentPixelFormat = Self.depthPixelFormat
        descriptor.vertexFunction = library.makeFunction(name: "star_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "star_fragment")

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create stars pipeline state: \(error)")
        }
    }

    private static func makeDepthStencilState(device: MTLDevice) -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .lessEqual
        descriptor.isDepthWriteEnabled = false
        guard let state = device.makeDepthStencilState(descriptor: descriptor) else {
            fatalError("Failed to create stars depth stencil state")
        }
        return state
    }
}

private struct StarUniforms {
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
    var sceneOrigin: SIMD3<Float>
}
