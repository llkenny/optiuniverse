import Foundation
import MetalKit
import simd

struct ProminenceParams {
    var time: Float
    var flipFps: Float
    var cols: Int32
    var rows: Int32
    var intensity: Float
    var hueShift: Float
    var noiseUV: SIMD2<Float>
}

final class ProminenceRenderer {
    private struct Vertex {
        var worldPos: SIMD3<Float>
        var corner: SIMD2<Float>
        var scale: Float
        var startPhase: Float
        var fpsMul: Float
        var padding: SIMD3<Float> = .zero
    }

    private struct Camera {
        var viewProj: float4x4
        var camRight: SIMD3<Float>
        var pad0: Float = 0
        var camUp: SIMD3<Float>
        var pad1: Float = 0
    }

    private struct TimingEntry {
        var angleDeg: Float
        var radiusMul: Float
        var lift: Float
        var scale: Float
        var fpsMul: Float
        var startPhase: Float
    }

    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private let sampler: MTLSamplerState
    private let flipbook: MTLTexture
    private let noise: MTLTexture
    private let vertexBuffer: MTLBuffer
    private let vertexCount: Int
    private var params: ProminenceParams

    init(device: MTLDevice, sunRadius: Float) {
        self.device = device
        self.pipelineState = ProminenceRenderer.makePipelineState(device: device)
        self.depthState = ProminenceRenderer.makeDepthState(device: device)
        self.sampler = ProminenceRenderer.makeSampler(device: device)
        self.flipbook = ProminenceRenderer.loadTexture(device: device, name: "prominence_flipbook")
        self.noise = ProminenceRenderer.loadTexture(device: device, name: "corona_noise_512")
        let timing = ProminenceRenderer.loadTiming(sunRadius: sunRadius)
        self.vertexBuffer = device.makeBuffer(bytes: timing.vertices,
                                             length: MemoryLayout<Vertex>.stride * timing.vertices.count,
                                             options: [])!
        self.vertexCount = timing.vertices.count
        self.params = ProminenceParams(time: 0,
                                       flipFps: timing.fps,
                                       cols: Int32(timing.cols),
                                       rows: Int32(timing.rows),
                                       intensity: timing.baseIntensity,
                                       hueShift: 0,
                                       noiseUV: SIMD2<Float>(4, 4))
    }

    func render(with renderEncoder: MTLRenderCommandEncoder,
                time: Float,
                viewMatrix: float4x4,
                projectionMatrix: float4x4) {
        var params = self.params
        params.time = time
        let invView = viewMatrix.inverse
        var cam = Camera(viewProj: projectionMatrix * viewMatrix,
                         camRight: SIMD3<Float>(invView.columns.0.x,
                                                invView.columns.0.y,
                                                invView.columns.0.z),
                         camUp: SIMD3<Float>(invView.columns.1.x,
                                             invView.columns.1.y,
                                             invView.columns.1.z))
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&cam, length: MemoryLayout<Camera>.stride, index: 1)
        renderEncoder.setVertexBytes(&params, length: MemoryLayout<ProminenceParams>.stride, index: 2)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<ProminenceParams>.stride, index: 1)
        renderEncoder.setFragmentTexture(flipbook, index: 0)
        renderEncoder.setFragmentTexture(noise, index: 1)
        renderEncoder.setFragmentSamplerState(sampler, index: 0)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount)
    }

    private static func makePipelineState(device: MTLDevice) -> MTLRenderPipelineState {
        let library = device.makeDefaultLibrary()!
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction = library.makeFunction(name: "promVS")
        descriptor.fragmentFunction = library.makeFunction(name: "promFS")
        let blend = descriptor.colorAttachments[0]!
        blend.isBlendingEnabled = true
        blend.rgbBlendOperation = .add
        blend.alphaBlendOperation = .add
        blend.sourceRGBBlendFactor = .one
        blend.destinationRGBBlendFactor = .one
        blend.sourceAlphaBlendFactor = .one
        blend.destinationAlphaBlendFactor = .one
        return try! device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeDepthState(device: MTLDevice) -> MTLDepthStencilState {
        let desc = MTLDepthStencilDescriptor()
        desc.depthCompareFunction = .lessEqual
        desc.isDepthWriteEnabled = false
        return device.makeDepthStencilState(descriptor: desc)!
    }

    private static func makeSampler(device: MTLDevice) -> MTLSamplerState {
        let desc = MTLSamplerDescriptor()
        desc.sAddressMode = .clampToEdge
        desc.tAddressMode = .clampToEdge
        desc.minFilter = .linear
        desc.magFilter = .linear
        return device.makeSamplerState(descriptor: desc)!
    }

    private static func loadTiming(sunRadius: Float) -> (vertices: [Vertex], cols: Int, rows: Int, fps: Float, baseIntensity: Float) {
        guard let url = Bundle.main.url(forResource: "prominence_flipbook_timing", withExtension: "txt") else {
            return ([], 1, 1, 12, 1)
        }
        let text = (try? String(contentsOf: url)) ?? ""
        var headerParsed = false
        var cols = 1
        var rows = 1
        var fps: Float = 12
        var baseIntensity: Float = 1
        var entries: [TimingEntry] = []
        for line in text.split(whereSeparator: { $0.isNewline }) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split { $0 == " " || $0 == "\t" }
            if !headerParsed {
                if parts.count >= 7 {
                    cols = Int(parts[1]) ?? 1
                    rows = Int(parts[2]) ?? 1
                    fps = Float(parts[3]) ?? 12
                    baseIntensity = Float(parts[4]) ?? 1
                }
                headerParsed = true
            } else {
                if parts.count >= 6 {
                    let e = TimingEntry(angleDeg: Float(parts[0]) ?? 0,
                                         radiusMul: Float(parts[1]) ?? 1,
                                         lift: Float(parts[2]) ?? 0,
                                         scale: Float(parts[3]) ?? 0.05,
                                         fpsMul: Float(parts[4]) ?? 1,
                                         startPhase: Float(parts[5]) ?? 0)
                    entries.append(e)
                }
            }
        }
        var vertices: [Vertex] = []
        for e in entries {
            let angle = e.angleDeg * (.pi / 180)
            let dir = SIMD3<Float>(cos(angle), sin(angle), 0)
            let base = sunRadius * e.radiusMul
            let pos = dir * (base + sunRadius * e.lift)
            let scale = sunRadius * e.scale
            let corners: [SIMD2<Float>] = [
                SIMD2<Float>(-0.5, -0.5),
                SIMD2<Float>( 0.5, -0.5),
                SIMD2<Float>(-0.5,  0.5),
                SIMD2<Float>(-0.5,  0.5),
                SIMD2<Float>( 0.5, -0.5),
                SIMD2<Float>( 0.5,  0.5)
            ]
            for c in corners {
                vertices.append(Vertex(worldPos: pos,
                                       corner: c,
                                       scale: scale,
                                       startPhase: e.startPhase,
                                       fpsMul: e.fpsMul))
            }
        }
        return (vertices, cols, rows, fps, baseIntensity)
    }

    private static func loadTexture(device: MTLDevice, name: String) -> MTLTexture {
        let loader = MTKTextureLoader(device: device)
        let url = Bundle.main.url(forResource: name, withExtension: "png")!
        return try! loader.newTexture(URL: url, options: [.origin: MTKTextureLoader.Origin.topLeft.rawValue])
    }
}
