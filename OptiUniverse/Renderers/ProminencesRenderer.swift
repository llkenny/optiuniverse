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
    private let sampler: MTLSamplerState
    private let particleBuffer: MTLBuffer
    private let particleCount: Int
    private let arcHeight: Float = 0.3
    private let lifetime: Float = 4.0
    private let sunRadius: Float
    private var flipbook: MTLTexture
    private let frameCount: Int
    private let fps: Float

    init(device: MTLDevice, sunRadius: Float, particleCount: Int = 512) {
        self.device = device
        self.sunRadius = sunRadius
        self.particleCount = particleCount

        let library = device.makeDefaultLibrary()!
        let computeFunction = library.makeFunction(name: "updateProminenceParticles")!
        computePipeline = try! device.makeComputePipelineState(function: computeFunction)

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
        let url = Bundle.main.url(forResource: "prominence_flipbook", withExtension: "png", subdirectory: "Assets/Flipbooks")
            ?? Bundle.main.url(forResource: "prominence_flipbook", withExtension: "png")
        flipbook = try! loader.newTexture(URL: url!, options: [.origin: MTKTextureLoader.Origin.topLeft.rawValue])

        let timingURL = Bundle.main.url(forResource: "prominence_flipbook_timing", withExtension: "txt", subdirectory: "Assets/Flipbooks")
            ?? Bundle.main.url(forResource: "prominence_flipbook_timing", withExtension: "txt")
        var tmpFrameCount = 16
        var tmpFPS: Float = 13.5
        if let url = timingURL, let text = try? String(contentsOf: url) {
            if let line = text.split(separator: "\n").first(where: { $0.hasPrefix("Frames") }),
               let value = line.split(separator: ":").last,
               let parsed = Int(value.trimmingCharacters(in: .whitespaces)) {
                tmpFrameCount = parsed
            }
            if let line = text.split(separator: "\n").first(where: { $0.contains("float fps") }),
               let value = line.split(separator: "=").last?.split(separator: ";").first,
               let parsed = Float(value.trimmingCharacters(in: .whitespaces)) {
                tmpFPS = parsed
            }
        }
        frameCount = tmpFrameCount
        fps = tmpFPS

        particleBuffer = device.makeBuffer(length: MemoryLayout<ProminenceParticle>.stride * particleCount, options: [])!
        let ptr = particleBuffer.contents().bindMemory(to: ProminenceParticle.self, capacity: particleCount)
        for i in 0..<particleCount {
            let angle = Float(i) / Float(particleCount) * (2 * .pi)
            let life = Float.random(in: 0..<lifetime)
            ptr[i] = ProminenceParticle(position: SIMD3<Float>(cos(angle), 0, sin(angle)), angle: angle, life: life)
        }
    }

    func update(commandBuffer: MTLCommandBuffer, time: Float, delta: Float) {
        let encoder = commandBuffer.makeComputeCommandEncoder()!
        encoder.setComputePipelineState(computePipeline)
        encoder.setBuffer(particleBuffer, offset: 0, index: 0)
        var count = UInt32(particleCount)
        encoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: 1)
        var height = arcHeight
        encoder.setBytes(&height, length: MemoryLayout<Float>.stride, index: 2)
        var life = lifetime
        encoder.setBytes(&life, length: MemoryLayout<Float>.stride, index: 3)
        var t = time
        encoder.setBytes(&t, length: MemoryLayout<Float>.stride, index: 4)
        var d = delta
        encoder.setBytes(&d, length: MemoryLayout<Float>.stride, index: 5)
        let threads = MTLSize(width: particleCount, height: 1, depth: 1)
        let threadgroupSize = MTLSize(width: min(computePipeline.maxTotalThreadsPerThreadgroup, particleCount), height: 1, depth: 1)
        encoder.dispatchThreads(threads, threadsPerThreadgroup: threadgroupSize)
        encoder.endEncoding()
    }

    func draw(with renderEncoder: MTLRenderCommandEncoder, mvpMatrix: float4x4, time: Float) {
        renderEncoder.setRenderPipelineState(renderPipeline)
        renderEncoder.setVertexBuffer(particleBuffer, offset: 0, index: 0)
        var mvp = mvpMatrix
        renderEncoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.stride, index: 1)
        var radius = sunRadius
        renderEncoder.setVertexBytes(&radius, length: MemoryLayout<Float>.stride, index: 2)
        var life = lifetime
        renderEncoder.setVertexBytes(&life, length: MemoryLayout<Float>.stride, index: 3)

        renderEncoder.setFragmentTexture(flipbook, index: 0)
        renderEncoder.setFragmentSamplerState(sampler, index: 0)
        renderEncoder.setFragmentBytes(&life, length: MemoryLayout<Float>.stride, index: 0)
        var t = time
        renderEncoder.setFragmentBytes(&t, length: MemoryLayout<Float>.stride, index: 1)
        var frames = Int32(frameCount)
        renderEncoder.setFragmentBytes(&frames, length: MemoryLayout<Int32>.stride, index: 2)
        var f = fps
        renderEncoder.setFragmentBytes(&f, length: MemoryLayout<Float>.stride, index: 3)

        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
    }
}

