import MetalKit
import simd

struct CoronaParams {
    var time: Float
    var coronaIntensity: Float
    var coronaScale: Float
    var flickerSpeed: Float
}

final class CoronaRenderer {
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private let samplerState: MTLSamplerState
    private let mesh: MTKMesh
    private let gradientTexture: MTLTexture
    private let noiseTexture: MTLTexture

    init(device: MTLDevice, sunRadius: Float) {
        self.device = device
        self.pipelineState = CoronaRenderer.makePipelineState(device: device)
        self.depthState = CoronaRenderer.makeDepthState(device: device)
        self.samplerState = CoronaRenderer.makeSamplerState(device: device)
        self.mesh = CoronaRenderer.createSphere(device: device, radius: sunRadius * 1.02)
        self.gradientTexture = CoronaRenderer.loadTexture(device: device, name: "corona_gradient_1024")
        self.noiseTexture = CoronaRenderer.loadTexture(device: device, name: "corona_noise_512")
    }

    func render(with renderEncoder: MTLRenderCommandEncoder,
                time: Float,
                viewMatrix: float4x4,
                projectionMatrix: float4x4,
                modelMatrix: float4x4) {
        var mvp = projectionMatrix * viewMatrix * modelMatrix
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setVertexBytes(&mvp,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 1)
        renderEncoder.setVertexBuffer(mesh.vertexBuffers[0].buffer,
                                      offset: 0,
                                      index: 0)

        renderEncoder.setFragmentTexture(gradientTexture, index: 0)
        renderEncoder.setFragmentTexture(noiseTexture, index: 1)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        var params = CoronaParams(time: time,
                                  coronaIntensity: 1.0,
                                  coronaScale: 0.6,
                                  flickerSpeed: 1.2)
        renderEncoder.setFragmentBytes(&params,
                                       length: MemoryLayout<CoronaParams>.stride,
                                       index: 0)

        guard let submesh = mesh.submeshes.first else { return }
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
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.sampleCount = 4
        descriptor.vertexFunction = library.makeFunction(name: "corona_sphere_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "corona_sphere_fragment")
        descriptor.vertexDescriptor = makeVertexDescriptor()
        return try! device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeDepthState(device: MTLDevice) -> MTLDepthStencilState {
        let desc = MTLDepthStencilDescriptor()
        desc.isDepthWriteEnabled = false
        desc.depthCompareFunction = .lessEqual
        return device.makeDepthStencilState(descriptor: desc)!
    }

    private static func makeSamplerState(device: MTLDevice) -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }

    private static func makeVertexDescriptor() -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 3
        return vertexDescriptor
    }

    private static func createSphere(device: MTLDevice, radius: Float) -> MTKMesh {
        let allocator = MTKMeshBufferAllocator(device: device)
        let mdlMesh = MDLMesh(
            sphereWithExtent: [radius * 2, radius * 2, radius * 2],
            segments: [20, 20],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: allocator
        )
        let mdlDescriptor = MTKModelIOVertexDescriptorFromMetal(makeVertexDescriptor())
        (mdlDescriptor.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        mdlMesh.vertexDescriptor = mdlDescriptor
        return try! MTKMesh(mesh: mdlMesh, device: device)
    }

    private static func loadTexture(device: MTLDevice, name: String) -> MTLTexture {
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .origin: MTKTextureLoader.Origin.topLeft.rawValue,
            .generateMipmaps: true
        ]
        let url = Bundle.main.url(forResource: name,
                                   withExtension: "png",
                                   subdirectory: "Corona")!
        return try! loader.newTexture(URL: url, options: options)
    }
}

