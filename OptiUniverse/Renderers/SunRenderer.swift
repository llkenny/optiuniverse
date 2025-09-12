//
//  SunRenderer.swift
//  OptiUniverse
//
//  Created for APP-03.
//

import MetalKit
import simd

/// Dedicated renderer for the Sun. Generates a procedural photosphere
/// and corona using the `fragment_sun` shader. The renderer exposes the
/// latest model matrix so other systems can align with the Sun in the
/// scene graph.
final class SunRenderer {
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private var mesh: MDLMesh
    private var texture: MTLTexture
    private var coronaGradient: MTLTexture
    private var coronaNoise: MTLTexture

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
        // Pre-build mesh and texture since the Sun's size does not change.
        self.mesh = SunRenderer.createTexturedSphere(device: device,
                                                     radius: sun.radius,
                                                     textureName: sun.textureName)
        self.texture = SunRenderer.loadTexture(device: device,
                                               name: sun.textureName)
        self.coronaGradient = SunRenderer.loadTexture(device: device,
                                                      name: "corona_gradient_1024")
        self.coronaNoise = SunRenderer.loadTexture(device: device,
                                                   name: "corona_noise_512")
    }

    /// Renders the Sun using the provided encoder.
    /// - Parameters:
    ///   - renderEncoder: Encoder from the main render pass.
    ///   - time: Global simulation time used for animation.
    ///   - delta: Time since last frame.
    ///   - viewMatrix: View matrix.
    ///   - projectionMatrix: Projection matrix.
    func renderSun(with renderEncoder: MTLRenderCommandEncoder,
                   time: Float,
                   delta: Float,
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

        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.setFragmentTexture(coronaGradient, index: 1)
        renderEncoder.setFragmentTexture(coronaNoise, index: 2)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        var t = time
        renderEncoder.setFragmentBytes(&t,
                                       length: MemoryLayout<Float>.stride,
                                       index: 0)
        var d = delta
        renderEncoder.setFragmentBytes(&d,
                                       length: MemoryLayout<Float>.stride,
                                       index: 1)
        var e = QualityManager.shared.exposure
        renderEncoder.setFragmentBytes(&e,
                                       length: MemoryLayout<Float>.stride,
                                       index: 2)

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
        descriptor.vertexFunction = library.makeFunction(name: "vertex_main")
        descriptor.fragmentFunction = library.makeFunction(name: "fragment_sun")
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
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
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
}

