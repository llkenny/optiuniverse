//
//  PlanetsRenderer+Make.swift
//  UniverseModule
//
//  Created by max on 07.05.2026.
//

import MetalKit

extension PlanetsRenderer {

    private static let colorPixelFormat: MTLPixelFormat = .rgba16Float
    private static let depthPixelFormat: MTLPixelFormat = .depth32Float

    static func makeDepthStencilState(device: MTLDevice,
                                      writesDepth: Bool) -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = writesDepth
        guard let state = device.makeDepthStencilState(descriptor: descriptor) else {
            fatalError("Failed to create planet depth stencil state")
        }
        return state
    }

    /// Builds a render pipeline for the given fragment function.
    ///
    /// - Parameter fragmentFunction: The name of the fragment shader function.
    /// - Returns: A configured `MTLRenderPipelineState`.
    func makePipelineState(fragmentFunction: String,
                           sampleCount: Int) -> MTLRenderPipelineState {
        let library = Self.makeShaderLibrary(device: device)

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.rasterSampleCount = sampleCount
        descriptor.colorAttachments[0].pixelFormat = Self.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        descriptor.depthAttachmentPixelFormat = Self.depthPixelFormat
        descriptor.vertexFunction = library.makeFunction(name: "vertex_main")
        descriptor.fragmentFunction = library.makeFunction(name: fragmentFunction)
        descriptor.vertexDescriptor = Self.makeVertexDescriptor()

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }

    func makeSamplerState() -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        samplerDescriptor.maxAnisotropy = 8
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }

    private static func makeShaderLibrary(device: MTLDevice) -> MTLLibrary {
        do {
            return try device.makeDefaultLibrary(bundle: .module)
        } catch {
            fatalError("Failed to load Metal shader library from UniverseModule bundle: \(error)")
        }
    }

    /// Creates the shared vertex descriptor for planet rendering.
    private static func makeVertexDescriptor() -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()

        // Position (attribute 0)
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        // Normal (attribute 1)
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = 0
        vertexDescriptor.attributes[1].bufferIndex = 1

        // Texture coordinates (attribute 2)
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = 0
        vertexDescriptor.attributes[2].bufferIndex = 2

        // Tangent (attribute 3)
        vertexDescriptor.attributes[3].format = .float4
        vertexDescriptor.attributes[3].offset = 0
        vertexDescriptor.attributes[3].bufferIndex = 3

        // Layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[1].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[2].stride = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.layouts[3].stride = MemoryLayout<SIMD4<Float>>.stride
        return vertexDescriptor
    }
}
