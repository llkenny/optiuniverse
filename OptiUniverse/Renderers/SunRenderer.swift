//
//  SunRenderer.swift
//  OptiUniverse
//
//  Created for APP-03.
//

import Foundation
import MetalKit
import simd

struct SunParams {
    var time: Float
    var flowScale: SIMD2<Float>
    var flowSpeed: Float
    var mixLowHigh: Float
    var granulationScale: Float
    var k: Float
    var gamma: Float
    var padding: Float = 0
}

/// Dedicated renderer for the Sun. Generates a procedural photosphere
/// using the `sun_surface_fragment` shader. The renderer exposes the
/// latest model matrix so other systems can align with the Sun in the
/// scene graph.
final class SunRenderer {
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private var mesh: MDLMesh
    private var noiseLow3D: MTLTexture
    private var noiseHigh3D: MTLTexture
    private var flowMap: MTLTexture
    private var sunspotMask: MTLTexture

    /// Model matrix without scaling. Updated every frame after calling
    /// `renderSun` so that other renderers can query the Sun's transform.
    var modelMatrix: float4x4 = matrix_identity_float4x4

    /// Screen-space center position of the Sun after the last render call.
    var screenPosition: SIMD2<Float>?
    /// World-space center position of the Sun after the last render call.
    var worldPosition: SIMD3<Float>?

    private let sun: Planet

    /// Radius of the Sun in scene units for camera framing.
    var radius: Float { sun.radius }
    /// Name of the rendered body for lookup convenience.
    var name: String { sun.name }

    init(device: MTLDevice) {
        self.device = device
        self.pipelineState = SunRenderer.makePipelineState(device: device)
        self.samplerState = SunRenderer.makeSamplerState(device: device)
        self.sun = SolarSystemLoader.loadPlanets(from: "sun").first!
        self.mesh = SunRenderer.createTexturedSphere(device: device,
                                                     radius: sun.radius,
                                                     textureName: sun.textureName)
        self.noiseLow3D = SunRenderer.load3DTexture(device: device,
                                                    name: "noise_low_128x128x128_f16")
        self.noiseHigh3D = SunRenderer.load3DTexture(device: device,
                                                     name: "noise_high_128x128x128_f16")
        self.flowMap = SunRenderer.loadTexture(device: device, name: "flow_map")
        self.sunspotMask = SunRenderer.loadTexture(device: device, name: "sunspot_mask_1024")
    }

    /// Renders the Sun using the provided encoder.
    /// - Parameters:
    ///   - renderEncoder: Encoder from the main render pass.
    ///   - time: Global simulation time used for animation.
    ///   - viewMatrix: View matrix.
    ///   - projectionMatrix: Projection matrix.
    func renderSun(with renderEncoder: MTLRenderCommandEncoder,
                   time: Float,
                   viewMatrix: float4x4,
                   projectionMatrix: float4x4,
                   viewportSize: CGSize) {
        // The Sun is placed at the origin but we keep transformation logic to
        // stay consistent with planets and allow future movement if needed.
        let rotation = float4x4.makeRotationZ(time * sun.orbitSpeed)
        let translation = float4x4.makeTranslation([sun.distance, 0, 0])
        modelMatrix = rotation * translation

        // Calculate world and screen positions for label overlays.
        let worldPos4 = modelMatrix * SIMD4<Float>(0, 0, 0, 1)
        worldPosition = SIMD3<Float>(worldPos4.x, worldPos4.y, worldPos4.z)
        let clip = projectionMatrix * viewMatrix * worldPos4
        if clip.w > 0 {
            let ndc = clip / clip.w
            if abs(ndc.x) <= 1, abs(ndc.y) <= 1, ndc.z >= 0, ndc.z <= 1 {
                let x = (ndc.x + 1) * 0.5 * Float(viewportSize.width)
                let y = (ndc.y + 1) * 0.5 * Float(viewportSize.height)
                screenPosition = SIMD2<Float>(x, y)
            } else {
                screenPosition = nil
            }
        } else {
            screenPosition = nil
        }

        var mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        let mtkMesh = try! MTKMesh(mesh: mesh, device: device)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBytes(&mvpMatrix,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 1)
        renderEncoder.setVertexBytes(&modelMatrix,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 2)
        renderEncoder.setVertexBuffer(mtkMesh.vertexBuffers[0].buffer,
                                      offset: 0,
                                      index: 0)

        renderEncoder.setFragmentTexture(noiseLow3D, index: 0)
        renderEncoder.setFragmentTexture(noiseHigh3D, index: 1)
        renderEncoder.setFragmentTexture(flowMap, index: 2)
        renderEncoder.setFragmentTexture(sunspotMask, index: 3)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        var params = SunParams(time: time,
                               flowScale: SIMD2<Float>(1, 1),
                               flowSpeed: 0.012,
                               mixLowHigh: 0.65,
                               granulationScale: 0.002,
                               k: 1.0,
                               gamma: 1.8)
        renderEncoder.setFragmentBytes(&params,
                                       length: MemoryLayout<SunParams>.stride,
                                       index: 0)

        guard let submesh = mtkMesh.submeshes.first else { return }
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: submesh.indexCount,
                                            indexType: submesh.indexType,
                                            indexBuffer: submesh.indexBuffer.buffer,
                                            indexBufferOffset: submesh.indexBuffer.offset)
    }

    // MARK: - Helpers

    private static func makePipelineState(device: MTLDevice) -> MTLRenderPipelineState {
        let library = device.makeDefaultLibrary()!
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        descriptor.sampleCount = 4
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction = library.makeFunction(name: "photosphere_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "sun_surface_fragment")
        descriptor.vertexDescriptor = makeVertexDescriptor()
        return try! device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeVertexDescriptor() -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 6
        vertexDescriptor.attributes[2].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 8
        return vertexDescriptor
    }

    private static func makeSamplerState(device: MTLDevice) -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .repeat
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }

    private static func createTexturedSphere(device: MTLDevice,
                                             radius: Float,
                                             textureName: String) -> MDLMesh {
        let allocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = MDLMesh(
            sphereWithExtent: [radius * 2, radius * 2, radius * 2],
            segments: [20, 20],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: allocator
        )
        let vertexDescriptor = MTKModelIOVertexDescriptorFromMetal(makeVertexDescriptor())
        (vertexDescriptor.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        (vertexDescriptor.attributes[1] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
        (vertexDescriptor.attributes[2] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
        mdlMesh.vertexDescriptor = vertexDescriptor
        return mdlMesh
    }

    private static func loadTexture(device: MTLDevice, name: String) -> MTLTexture {
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .origin: MTKTextureLoader.Origin.topLeft.rawValue,
            .generateMipmaps: true
        ]
        let url = Bundle.main.url(forResource: name, withExtension: "png")!
        return try! loader.newTexture(URL: url, options: options)
    }

    private static func load3DTexture(device: MTLDevice, name: String,
                                      width: Int = 128,
                                      height: Int = 128,
                                      depth: Int = 128) -> MTLTexture {
        let url = Bundle.main.url(forResource: name, withExtension: "raw")!
        let data = try! Data(contentsOf: url)
        let bytesPerElement = MemoryLayout<UInt16>.size // float16
        let bytesPerRow = width * bytesPerElement
        let bytesPerImage = bytesPerRow * height
        precondition(data.count == bytesPerImage * depth, "Unexpected RAW size")

        let desc = MTLTextureDescriptor()
        desc.textureType = .type3D
        desc.pixelFormat = .r16Float
        desc.width = width
        desc.height = height
        desc.depth = depth
        // The texture data is uploaded from the CPU, therefore the storage
        // mode must allow CPU access. Using `.private` causes a runtime crash
        // when calling `replaceRegion` (CPU access is disallowed). `.shared`
        // lets us populate the texture once on load while still keeping it
        // GPU-accessible.
        desc.storageMode = .shared
        desc.usage = [.shaderRead]
        let texture = device.makeTexture(descriptor: desc)!

        data.withUnsafeBytes { ptr in
            let region = MTLRegion(origin: .init(x: 0, y: 0, z: 0),
                                   size: .init(width: width, height: height, depth: depth))
            texture.replace(region: region,
                            mipmapLevel: 0,
                            slice: 0,
                            withBytes: ptr.baseAddress!,
                            bytesPerRow: bytesPerRow,
                            bytesPerImage: bytesPerImage)
        }
        return texture
    }
}

