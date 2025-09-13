import Foundation
import MetalKit
import simd

struct ProminenceParticle {
    var position: SIMD3<Float>
    var angle: Float
    var life: Float
    var pad: Float = 0
}

final class ProminencesRenderer {
    private let device: MTLDevice
    private let computePipeline: MTLComputePipelineState
    private let renderPipeline: MTLRenderPipelineState
    private let sampler: MTLSamplerState
    private let texture: MTLTexture
    private let particleCount: Int
    private var particleBuffer: MTLBuffer

    private var lifetime: Float = 5.0
    private var arcHeight: Float = 0.2

    init(device: MTLDevice, particleCount: Int = 512) {
        self.device = device
        self.particleCount = particleCount
        let library = device.makeDefaultLibrary()!
        computePipeline = try! device.makeComputePipelineState(function: library.makeFunction(name: "updateProminenceParticles")!)

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        descriptor.sampleCount = 4
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction = library.makeFunction(name: "prominence_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "prominence_fragment")
        let blend = descriptor.colorAttachments[0]!
        blend.isBlendingEnabled = true
        blend.rgbBlendOperation = .add
        blend.alphaBlendOperation = .add
        blend.sourceRGBBlendFactor = .one
        blend.destinationRGBBlendFactor = .one
        blend.sourceAlphaBlendFactor = .one
        blend.destinationAlphaBlendFactor = .one
        renderPipeline = try! device.makeRenderPipelineState(descriptor: descriptor)

        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerDesc.mipFilter = .linear
        samplerDesc.sAddressMode = .clampToEdge
        samplerDesc.tAddressMode = .clampToEdge
        sampler = device.makeSamplerState(descriptor: samplerDesc)!

        let loader = MTKTextureLoader(device: device)
        let url = Bundle.main.url(forResource: "prominence_flipbook", withExtension: "png")!
        texture = try! loader.newTexture(URL: url, options: [.origin: MTKTextureLoader.Origin.topLeft.rawValue])

        particleBuffer = device.makeBuffer(length: MemoryLayout<ProminenceParticle>.stride * particleCount, options: [])!
        resetParticles()
    }

    private func resetParticles() {
        let pointer = particleBuffer.contents().bindMemory(to: ProminenceParticle.self, capacity: particleCount)
        for i in 0..<particleCount {
            pointer[i] = ProminenceParticle(position: SIMD3<Float>(repeating: 0), angle: 0, life: 0, pad: 0)
        }
    }

    func update(commandBuffer: MTLCommandBuffer, time: Float, delta: Float) {
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        computeEncoder.setComputePipelineState(computePipeline)
        computeEncoder.setBuffer(particleBuffer, offset: 0, index: 0)
        var count = UInt32(particleCount)
        var arc = arcHeight
        var life = lifetime
        var t = time
        var d = delta
        computeEncoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: 1)
        computeEncoder.setBytes(&arc, length: MemoryLayout<Float>.stride, index: 2)
        computeEncoder.setBytes(&life, length: MemoryLayout<Float>.stride, index: 3)
        computeEncoder.setBytes(&t, length: MemoryLayout<Float>.stride, index: 4)
        computeEncoder.setBytes(&d, length: MemoryLayout<Float>.stride, index: 5)
        let threads = MTLSize(width: particleCount, height: 1, depth: 1)
        let tgWidth = min(computePipeline.maxTotalThreadsPerThreadgroup, particleCount)
        let tg = MTLSize(width: tgWidth, height: 1, depth: 1)
        computeEncoder.dispatchThreads(threads, threadsPerThreadgroup: tg)
        computeEncoder.endEncoding()
    }

    func render(with renderEncoder: MTLRenderCommandEncoder,
                viewMatrix: float4x4,
                projectionMatrix: float4x4,
                modelMatrix: float4x4,
                time: Float) {
        var mvp = projectionMatrix * viewMatrix * modelMatrix
        renderEncoder.setRenderPipelineState(renderPipeline)
        renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.stride, index: 1)
        var life = lifetime
        renderEncoder.setVertexBytes(&life, length: MemoryLayout<Float>.stride, index: 2)
        renderEncoder.setFragmentBytes(&life, length: MemoryLayout<Float>.stride, index: 0)
        var t = time
        renderEncoder.setFragmentBytes(&t, length: MemoryLayout<Float>.stride, index: 1)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.setFragmentSamplerState(sampler, index: 0)
        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
    }
}
