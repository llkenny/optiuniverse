import Foundation
import MetalKit
import simd

struct CoronaParams {
    var cameraPos: SIMD3<Float>
    var time: Float
    var intensity: Float
    var scale: Float
    var flickerSpeed: Float
}

final class CoronaRenderer {
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private let samplerState: MTLSamplerState
    private let mesh: MDLMesh
    private let gradient: MTLTexture
    private let noise: MTLTexture

    init(device: MTLDevice, sunRadius: Float) {
        self.device = device
        self.pipelineState = CoronaRenderer.makePipelineState(device: device)
        self.depthState = CoronaRenderer.makeDepthState(device: device)
        self.samplerState = CoronaRenderer.makeSamplerState(device: device)
        self.gradient = CoronaRenderer.loadTexture(device: device,
                                                   name: "corona_gradient_1024",
                                                   subdirectory: "Assets/Corona")
        self.noise = CoronaRenderer.loadTexture(device: device,
                                                name: "corona_noise_512",
                                                subdirectory: "Assets/Corona")
        self.mesh = CoronaRenderer.createSphere(device: device, radius: sunRadius * 1.1)
    }

    func render(with renderEncoder: MTLRenderCommandEncoder,
                time: Float,
                modelMatrix: float4x4,
                viewMatrix: float4x4,
                projectionMatrix: float4x4,
                cameraPosition: SIMD3<Float>) {
        var mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        let mtkMesh = try! MTKMesh(mesh: mesh, device: device)

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setVertexBytes(&mvpMatrix,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 1)
        renderEncoder.setVertexBytes(&modelMatrix,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 2)
        renderEncoder.setVertexBuffer(mtkMesh.vertexBuffers[0].buffer,
                                      offset: 0,
                                      index: 0)

        var params = CoronaParams(cameraPos: cameraPosition,
                                  time: time,
                                  intensity: 1.0,
                                  scale: 0.6,
                                  flickerSpeed: 1.2)
        renderEncoder.setFragmentBytes(&params,
                                       length: MemoryLayout<CoronaParams>.stride,
                                       index: 0)
        renderEncoder.setFragmentTexture(gradient, index: 0)
        renderEncoder.setFragmentTexture(noise, index: 1)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        guard let submesh = mtkMesh.submeshes.first else { return }
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: submesh.indexCount,
                                            indexType: submesh.indexType,
                                            indexBuffer: submesh.indexBuffer.buffer,
                                            indexBufferOffset: submesh.indexBuffer.offset)
    }

    private static func makePipelineState(device: MTLDevice) -> MTLRenderPipelineState {
        let library = device.makeDefaultLibrary()!
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        descriptor.sampleCount = 4
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction = library.makeFunction(name: "corona_sphere_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "corona_sphere_fragment")
        descriptor.vertexDescriptor = makeVertexDescriptor()
        let attachment = descriptor.colorAttachments[0]
        attachment?.isBlendingEnabled = true
        attachment?.rgbBlendOperation = .add
        attachment?.alphaBlendOperation = .add
        attachment?.sourceRGBBlendFactor = .one
        attachment?.destinationRGBBlendFactor = .one
        attachment?.sourceAlphaBlendFactor = .one
        attachment?.destinationAlphaBlendFactor = .one
        return try! device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeDepthState(device: MTLDevice) -> MTLDepthStencilState {
        let desc = MTLDepthStencilDescriptor()
        desc.depthCompareFunction = .lessEqual
        desc.isDepthWriteEnabled = false
        return device.makeDepthStencilState(descriptor: desc)!
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

    private static func createSphere(device: MTLDevice, radius: Float) -> MDLMesh {
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

    private static func makeSamplerState(device: MTLDevice) -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .repeat
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }

    private static func loadTexture(device: MTLDevice, name: String, subdirectory: String) -> MTLTexture {
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .origin: MTKTextureLoader.Origin.topLeft.rawValue,
            .generateMipmaps: true
        ]
        let url = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: subdirectory)!
        return try! loader.newTexture(URL: url, options: options)
    }
}

