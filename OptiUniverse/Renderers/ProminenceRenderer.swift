//
//  ProminenceRenderer.swift
//  OptiUniverse
//
//  Renders animated solar prominences along the Sun's limb using a
//  flipbook texture atlas. Particle positions are updated on the GPU
//  via `updateProminenceParticles` compute kernel and rendered as point
//  sprites that billboard towards the camera. The UV coordinates are
//  animated according to the timing guide in
//  `Assets/Flipbooks/prominence_flipbook_timing.txt`.
//

import Foundation
import MetalKit
import simd

/// CPU-side mirror of the Metal `ProminenceParticle` struct.
/// Memory layout must match the shader definition.
private struct ProminenceParticle {
    var position: SIMD3<Float> = .zero
    var angle: Float = 0
    var life: Float = 0
    var padding: Float = 0 // 16-byte alignment
}

/// Renderer responsible for updating and drawing solar prominences.
final class ProminenceRenderer {
    private let device: MTLDevice
    private let computePipeline: MTLComputePipelineState
    private let renderPipeline: MTLRenderPipelineState
    private let sampler: MTLSamplerState
    private let texture: MTLTexture

    private var particles: MTLBuffer
    private let particleCount: Int = 32
    private let lifetime: Float = 5.0
    private let arcHeight: Float = 0.3
    private let sunRadius: Float

    private let frameCount: UInt32
    private let fps: Float

    init(device: MTLDevice, sunRadius: Float) {
        self.device = device
        self.sunRadius = sunRadius

        let library = device.makeDefaultLibrary()!
        let computeFunc = library.makeFunction(name: "updateProminenceParticles")!
        computePipeline = try! device.makeComputePipelineState(function: computeFunc)

        let renderDesc = MTLRenderPipelineDescriptor()
        renderDesc.colorAttachments[0].pixelFormat = .rgba16Float
        renderDesc.sampleCount = 4
        renderDesc.depthAttachmentPixelFormat = .depth32Float
        renderDesc.vertexFunction = library.makeFunction(name: "prominence_vertex")
        renderDesc.fragmentFunction = library.makeFunction(name: "prominence_fragment")
        let blend = renderDesc.colorAttachments[0]!
        blend.isBlendingEnabled = true
        blend.rgbBlendOperation = .add
        blend.alphaBlendOperation = .add
        blend.sourceRGBBlendFactor = .one
        blend.sourceAlphaBlendFactor = .one
        blend.destinationRGBBlendFactor = .one
        blend.destinationAlphaBlendFactor = .one
        renderPipeline = try! device.makeRenderPipelineState(descriptor: renderDesc)

        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.sAddressMode = .clampToEdge
        samplerDesc.tAddressMode = .clampToEdge
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerDesc.mipFilter = .linear
        sampler = device.makeSamplerState(descriptor: samplerDesc)!

        texture = ProminenceRenderer.loadTexture(device: device)
        let timing = ProminenceRenderer.loadTiming()
        frameCount = UInt32(timing.frames)
        fps = timing.fps

        particles = device.makeBuffer(length: MemoryLayout<ProminenceParticle>.stride * particleCount,
                                      options: .storageModeShared)!
        // Initialise particles with zero life so compute kernel respawns them.
        let ptr = particles.contents().bindMemory(to: ProminenceParticle.self, capacity: particleCount)
        for i in 0..<particleCount {
            ptr[i] = ProminenceParticle()
        }
    }

    /// Updates particle positions using the compute kernel.
    func update(commandBuffer: MTLCommandBuffer, delta: Float, time: Float) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        encoder.setComputePipelineState(computePipeline)
        encoder.setBuffer(particles, offset: 0, index: 0)
        var count = UInt32(particleCount)
        encoder.setBytes(&count, length: MemoryLayout<UInt32>.stride, index: 1)
        var height = arcHeight
        encoder.setBytes(&height, length: MemoryLayout<Float>.stride, index: 2)
        var life = lifetime
        encoder.setBytes(&life, length: MemoryLayout<Float>.stride, index: 3)
        var t = time
        encoder.setBytes(&t, length: MemoryLayout<Float>.stride, index: 4)
        var dt = delta
        encoder.setBytes(&dt, length: MemoryLayout<Float>.stride, index: 5)

        let threads = MTLSize(width: particleCount, height: 1, depth: 1)
        let w = computePipeline.maxTotalThreadsPerThreadgroup
        let tg = MTLSize(width: min(particleCount, w), height: 1, depth: 1)
        encoder.dispatchThreads(threads, threadsPerThreadgroup: tg)
        encoder.endEncoding()
    }

    /// Renders the current particles as billboards.
    func render(with renderEncoder: MTLRenderCommandEncoder,
                viewMatrix: float4x4,
                projectionMatrix: float4x4,
                sunModelMatrix: float4x4,
                time: Float) {
        var mvp = projectionMatrix * viewMatrix * sunModelMatrix
        renderEncoder.setRenderPipelineState(renderPipeline)
        renderEncoder.setVertexBuffer(particles, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&mvp, length: MemoryLayout<float4x4>.stride, index: 1)
        var life = lifetime
        renderEncoder.setVertexBytes(&life, length: MemoryLayout<Float>.stride, index: 2)
        var radius = sunRadius
        renderEncoder.setVertexBytes(&radius, length: MemoryLayout<Float>.stride, index: 3)

        renderEncoder.setFragmentBytes(&life, length: MemoryLayout<Float>.stride, index: 0)
        var t = time
        renderEncoder.setFragmentBytes(&t, length: MemoryLayout<Float>.stride, index: 1)
        var frames = frameCount
        renderEncoder.setFragmentBytes(&frames, length: MemoryLayout<UInt32>.stride, index: 2)
        var rate = fps
        renderEncoder.setFragmentBytes(&rate, length: MemoryLayout<Float>.stride, index: 3)
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.setFragmentSamplerState(sampler, index: 0)

        renderEncoder.drawPrimitives(type: .point, vertexStart: 0, vertexCount: particleCount)
    }

    // MARK: - Helpers

    private static func loadTexture(device: MTLDevice) -> MTLTexture {
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .origin: MTKTextureLoader.Origin.topLeft.rawValue,
            .generateMipmaps: true
        ]
        let url = Bundle.main.url(forResource: "Flipbooks/prominence_flipbook", withExtension: "png")!
        return try! loader.newTexture(URL: url, options: options)
    }

    /// Parses the timing guide to extract frame count and FPS.
    private static func loadTiming() -> (frames: Int, fps: Float) {
        guard let url = Bundle.main.url(forResource: "Flipbooks/prominence_flipbook_timing",
                                        withExtension: "txt"),
              let text = try? String(contentsOf: url) else {
            return (16, 13.5)
        }
        var frames = 16
        var fps: Float = 13.5
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Frames:") {
                let comps = trimmed.split(separator: ":")
                if comps.count > 1 { frames = Int(comps[1].trimmingCharacters(in: .whitespaces)) ?? frames }
            } else if trimmed.hasPrefix("Playback:") {
                // Extract numbers such as "12-15 FPS" and average them
                let numbers = trimmed.components(separatedBy: CharacterSet.decimalDigits.inverted)
                    .compactMap { Int($0) }
                if numbers.count >= 2 {
                    fps = Float(numbers[0] + numbers[1]) / 2.0
                } else if let first = numbers.first {
                    fps = Float(first)
                }
            }
        }
        return (frames, fps)
    }
}

