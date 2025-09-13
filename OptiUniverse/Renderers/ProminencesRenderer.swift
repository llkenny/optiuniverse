import Foundation
import MetalKit
import simd

struct ProminenceParticle {
    var position: SIMD3<Float>
    var angle: Float
    var life: Float
}

final class ProminencesRenderer {
    private let device: MTLDevice
    private let computePipeline: MTLComputePipelineState
    private let renderPipeline: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private let flipbookTexture: MTLTexture
    private var particleBuffer: MTLBuffer
    private let particleCount: Int
    private let arcHeight: Float = 0.3
    private let lifetime: Float = 2.0
    private let sunRadius: Float

    init(device: MTLDevice, sunRadius: Float, particleCount: Int = 512) {
        self.device = device
        self.sunRadius = sunRadius
        self.particleCount = particleCount

        let library = device.makeDefaultLibrary()!
        let updateFunction = library.makeFunction(name: "updateProminenceParticles")!
        computePipeline = try! device.makeComputePipelineState(function: updateFunction)

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        descriptor.sampleCount = 4
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction = library.makeFunction(name: "prominence_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "prominence_fragment")
        if let blend = descriptor.colorAttachments[0] {
            blend.isBlendingEnabled = true
            blend.rgbBlendOperation = .add
            blend.alphaBlendOperation = .add
            blend.sourceRGBBlendFactor = .one
            blend.destinationRGBBlendFactor = .one
            blend.sourceAlphaBlendFactor = .one
            blend.destinationAlphaBlendFactor = .one
        }
        renderPipeline = try! device.makeRenderPipelineState(descriptor: descriptor)

        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.sAddressMode = .clampToEdge
        samplerDesc.tAddressMode = .clampToEdge
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerDesc.mipFilter = .linear
        samplerState = device.makeSamplerState(descriptor: samplerDesc)!

        particleBuffer = device.makeBuffer(length: MemoryLayout<ProminenceParticle>.stride * particleCount,
                                           options: .storageModeShared)!
        let pointer = particleBuffer.contents().bindMemory(to: ProminenceParticle.self, capacity: particleCount)
        for i in 0..<particleCount {
            pointer[i] = ProminenceParticle(position: .zero, angle: 0, life: 0)
        }

        let loader = MTKTextureLoader(device: device)
        let url = Bundle.main.url(forResource: "prominence_flipbook", withExtension: "png", subdirectory: "Flipbooks")!
        flipbookTexture = try! loader.newTexture(URL: url, options: [.origin: MTKTextureLoader.Origin.topLeft.rawValue])
    }

    func update(commandBuffer: MTLCommandBuffer, time: Float, delta: Float) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(computePipeline)
        encoder.setBuffer(particleBuffer, offset: 0, index: 0)
        var count = UInt32(particleCount)
        encoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: 1)
        var arc = arcHeight
        encoder.setBytes(&arc, length: MemoryLayout<Float>.stride, index: 2)
        var life = lifetime
        encoder.setBytes(&life, length: MemoryLayout<Float>.stride, index: 3)
        var t = time
        encoder.setBytes(&t, length: MemoryLayout<Float>.stride, index: 4)
        var d = delta
        encoder.setBytes(&d, length: MemoryLayout<Float>.stride, index: 5)
        let threadsPerGroup = MTLSize(width: computePipeline.threadExecutionWidth, height: 1, depth: 1)
        let threads = MTLSize(width: particleCount, height: 1, depth: 1)
        encoder.dispatchThreads(threads, threadsPerThreadgroup: threadsPerGroup)
        encoder.endEncoding()
    }

    func render(with renderEncoder: MTLRenderCommandEncoder,
                time: Float,
                viewMatrix: float4x4,
                projectionMatrix: float4x4,
                modelMatrix: float4x4) {
        var scale = float4x4.makeScale(SIMD3<Float>(repeating: sunRadius))
        var mvp = projectionMatrix * viewMatrix * modelMatrix * scale
        var life = lifetime
        var currentTime = time

        renderEncoder.setRenderPipelineState(renderPipeline)
        renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.stride, index: 1)
        renderEncoder.setVertexBytes(&life, length: MemoryLayout<Float>.stride, index: 2)

        renderEncoder.setFragmentBytes(&life, length: MemoryLayout<Float>.stride, index: 0)
        renderEncoder.setFragmentBytes(&currentTime, length: MemoryLayout<Float>.stride, index: 1)
        renderEncoder.setFragmentTexture(flipbookTexture, index: 0)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
    }
}

