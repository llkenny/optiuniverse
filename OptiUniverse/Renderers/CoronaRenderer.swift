import Foundation
import MetalKit
import simd

struct CoronaParams {
    var cameraPos: SIMD3<Float>
    var sunPos: SIMD3<Float>
    var time: Float
    var intensity: Float
    var noiseScale: Float
    var noiseSpeed: Float
}

final class CoronaRenderer {
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private var mesh: MDLMesh
    private var gradient: MTLTexture
    private var noise: MTLTexture

    init(device: MTLDevice, sunRadius: Float) {
        self.device = device
        self.pipelineState = CoronaRenderer.makePipelineState(device: device)
        self.samplerState = CoronaRenderer.makeSamplerState(device: device)
        self.mesh = CoronaRenderer.createSphere(device: device, radius: sunRadius * 1.1)
        self.gradient = CoronaRenderer.loadTexture(device: device, name: "corona_gradient_1024")
        self.noise = CoronaRenderer.loadTexture(device: device, name: "corona_noise_512")
    }

    func render(with renderEncoder: MTLRenderCommandEncoder,
                time: Float,
                viewMatrix: float4x4,
                projectionMatrix: float4x4,
                modelMatrix: float4x4,
                sunWorldPosition: SIMD3<Float>,
                cameraPosition: SIMD3<Float>) {
        var mvp = projectionMatrix * viewMatrix * modelMatrix
        let mtkMesh = try! MTKMesh(mesh: mesh, device: device)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.stride, index: 1)
        renderEncoder.setVertexBytes(&modelMatrix, length: MemoryLayout<float4x4>.stride, index: 2)
        renderEncoder.setVertexBuffer(mtkMesh.vertexBuffers[0].buffer, offset: 0, index: 0)

        renderEncoder.setFragmentTexture(gradient, index: 0)
        renderEncoder.setFragmentTexture(noise, index: 1)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        var params = CoronaParams(cameraPos: cameraPosition,
                                  sunPos: sunWorldPosition,
                                  time: time,
                                  intensity: 1.0,
                                  noiseScale: 2.0,
                                  noiseSpeed: 0.5)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<CoronaParams>.stride, index: 0)

        guard let sub = mtkMesh.submeshes.first else { return }
        renderEncoder.drawIndexedPrimitives(type: .triangle,
                                            indexCount: sub.indexCount,
                                            indexType: sub.indexType,
                                            indexBuffer: sub.indexBuffer.buffer,
                                            indexBufferOffset: sub.indexBuffer.offset)
    }

    private static func makePipelineState(device: MTLDevice) -> MTLRenderPipelineState {
        let library = device.makeDefaultLibrary()!
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        descriptor.sampleCount = 4
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction = library.makeFunction(name: "corona_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "corona_sphere_fragment")
        descriptor.vertexDescriptor = makeVertexDescriptor()
        let blend = descriptor.colorAttachments[0]
        blend?.isBlendingEnabled = true
        blend?.rgbBlendOperation = .add
        blend?.alphaBlendOperation = .add
        blend?.sourceRGBBlendFactor = .one
        blend?.destinationRGBBlendFactor = .one
        blend?.sourceAlphaBlendFactor = .one
        blend?.destinationAlphaBlendFactor = .one
        return try! device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeVertexDescriptor() -> MTLVertexDescriptor {
        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float3
        vd.attributes[0].offset = 0
        vd.attributes[0].bufferIndex = 0
        vd.attributes[1].format = .float3
        vd.attributes[1].offset = MemoryLayout<Float>.stride * 3
        vd.attributes[1].bufferIndex = 0
        vd.attributes[2].format = .float2
        vd.attributes[2].offset = MemoryLayout<Float>.stride * 6
        vd.attributes[2].bufferIndex = 0
        vd.layouts[0].stride = MemoryLayout<Float>.stride * 8
        return vd
    }

    private static func makeSamplerState(device: MTLDevice) -> MTLSamplerState {
        let desc = MTLSamplerDescriptor()
        desc.sAddressMode = .clampToEdge
        desc.tAddressMode = .clampToEdge
        desc.minFilter = .linear
        desc.magFilter = .linear
        desc.mipFilter = .linear
        return device.makeSamplerState(descriptor: desc)!
    }

    private static func createSphere(device: MTLDevice, radius: Float) -> MDLMesh {
        let allocator = MTKMeshBufferAllocator(device: device)
        let mdl = MDLMesh(sphereWithExtent: [radius * 2, radius * 2, radius * 2],
                          segments: [20, 20],
                          inwardNormals: false,
                          geometryType: .triangles,
                          allocator: allocator)
        let vd = MTKModelIOVertexDescriptorFromMetal(makeVertexDescriptor())
        (vd.attributes[0] as! MDLVertexAttribute).name = MDLVertexAttributePosition
        (vd.attributes[1] as! MDLVertexAttribute).name = MDLVertexAttributeNormal
        (vd.attributes[2] as! MDLVertexAttribute).name = MDLVertexAttributeTextureCoordinate
        mdl.vertexDescriptor = vd
        return mdl
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

