import Foundation
import MetalKit
import simd

struct ProminenceParams {
    var time: Float = 0
    var flipFps: Float = 0
    var cols: Int32 = 1
    var rows: Int32 = 1
    var intensity: Float = 1
    var hueShift: Float = 0
    var noiseUV: SIMD2<Float> = SIMD2<Float>(1, 1)
}

struct ProminenceVertex {
    var worldPos: SIMD3<Float>
    var corner: SIMD2<Float>
    var scale: Float
    var startPhase: Float
    var fpsMul: Float
}

struct CameraData {
    var viewProj: float4x4
    var camRight: SIMD3<Float>
    var pad1: Float = 0
    var camUp: SIMD3<Float>
    var pad2: Float = 0
}

final class ProminenceRenderer {
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private let flipbook: MTLTexture
    private let noise: MTLTexture
    private let vertexBuffer: MTLBuffer
    private var params: ProminenceParams
    private let vertexCount: Int

    init(device: MTLDevice, sunRadius: Float) {
        self.device = device
        self.pipelineState = ProminenceRenderer.makePipelineState(device: device)
        self.samplerState = ProminenceRenderer.makeSamplerState(device: device)
        self.flipbook = ProminenceRenderer.loadTexture(device: device, name: "prominence_flipbook")
        self.noise = ProminenceRenderer.loadTexture(device: device, name: "corona_noise_512")
        let timing = ProminenceRenderer.loadTiming(device: device,
                                                   sunRadius: sunRadius)
        self.vertexBuffer = timing.buffer
        self.params = timing.params
        self.vertexCount = timing.vertexCount
    }

    func render(with renderEncoder: MTLRenderCommandEncoder,
                time: Float,
                viewMatrix: float4x4,
                projectionMatrix: float4x4) {
        var camera = CameraData(viewProj: projectionMatrix * viewMatrix,
                                camRight: SIMD3<Float>(viewMatrix.columns.0.x,
                                                       viewMatrix.columns.0.y,
                                                       viewMatrix.columns.0.z),
                                camUp: SIMD3<Float>(viewMatrix.columns.1.x,
                                                    viewMatrix.columns.1.y,
                                                    viewMatrix.columns.1.z))
        params.time = time

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&camera, length: MemoryLayout<CameraData>.stride, index: 1)
        renderEncoder.setVertexBytes(&params, length: MemoryLayout<ProminenceParams>.stride, index: 2)

        renderEncoder.setFragmentTexture(flipbook, index: 0)
        renderEncoder.setFragmentTexture(noise, index: 1)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<ProminenceParams>.stride, index: 0)

        renderEncoder.drawPrimitives(type: .triangle,
                                     vertexStart: 0,
                                     vertexCount: vertexCount)
    }

    private static func loadTiming(device: MTLDevice,
                                   sunRadius: Float) -> (buffer: MTLBuffer, params: ProminenceParams, vertexCount: Int) {
        var params = ProminenceParams()
        var vertices: [ProminenceVertex] = []
        if let url = Bundle.main.url(forResource: "prominence_flipbook_timing", withExtension: "txt"),
           let text = try? String(contentsOf: url) {
            let lines = text.split(whereSeparator: { $0.isNewline })
            var dataLines: [Substring] = []
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
                dataLines.append(Substring(trimmed))
            }
            if dataLines.count > 0 {
                let header = dataLines[0].split{ $0 == " " }
                if header.count >= 7 {
                    params.flipFps = Float(header[3]) ?? 16
                    params.cols = Int32(header[1]) ?? 1
                    params.rows = Int32(header[2]) ?? 1
                    params.intensity = Float(header[4]) ?? 1
                }
                for line in dataLines.dropFirst() {
                    let comps = line.split{ $0 == " " }
                    if comps.count < 6 { continue }
                    let angle = (Float(comps[0]) ?? 0) * (.pi / 180)
                    let radiusMul = Float(comps[1]) ?? 1
                    let lift = Float(comps[2]) ?? 0
                    let scale = Float(comps[3]) ?? 0.05
                    let fpsMul = Float(comps[4]) ?? 1
                    let startPhase = Float(comps[5]) ?? 0

                    let dir = SIMD3<Float>(cos(angle), 0, sin(angle))
                    let pos = dir * sunRadius * radiusMul + SIMD3<Float>(0, sunRadius * lift, 0)
                    let size = scale * sunRadius
                    let corners: [SIMD2<Float>] = [
                        SIMD2(-0.5, -0.5), SIMD2( 0.5, -0.5), SIMD2(-0.5,  0.5),
                        SIMD2( 0.5, -0.5), SIMD2( 0.5,  0.5), SIMD2(-0.5,  0.5)
                    ]
                    for corner in corners {
                        vertices.append(ProminenceVertex(worldPos: pos,
                                                         corner: corner,
                                                         scale: size,
                                                         startPhase: startPhase,
                                                         fpsMul: fpsMul))
                    }
                }
            }
        }
        let buffer = device.makeBuffer(bytes: vertices,
                                       length: vertices.count * MemoryLayout<ProminenceVertex>.stride,
                                       options: [])!
        return (buffer, params, vertices.count)
    }

    private static func loadTexture(device: MTLDevice, name: String) -> MTLTexture {
        let loader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option: Any] = [
            .origin: MTKTextureLoader.Origin.topLeft.rawValue,
            .SRGB: false
        ]
        let url = Bundle.main.url(forResource: name, withExtension: "png")!
        return try! loader.newTexture(URL: url, options: options)
    }

    private static func makeSamplerState(device: MTLDevice) -> MTLSamplerState {
        let desc = MTLSamplerDescriptor()
        desc.minFilter = .linear
        desc.magFilter = .linear
        desc.mipFilter = .linear
        desc.sAddressMode = .clampToEdge
        desc.tAddressMode = .clampToEdge
        return device.makeSamplerState(descriptor: desc)!
    }

    private static func makePipelineState(device: MTLDevice) -> MTLRenderPipelineState {
        let library = device.makeDefaultLibrary()!
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        descriptor.sampleCount = 4
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction = library.makeFunction(name: "prom_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "prom_fragment")
        descriptor.vertexDescriptor = makeVertexDescriptor()
        let blend = descriptor.colorAttachments[0]!
        blend.isBlendingEnabled = true
        blend.rgbBlendOperation = .add
        blend.alphaBlendOperation = .add
        blend.sourceRGBBlendFactor = .one
        blend.sourceAlphaBlendFactor = .one
        blend.destinationRGBBlendFactor = .one
        blend.destinationAlphaBlendFactor = .one
        return try! device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeVertexDescriptor() -> MTLVertexDescriptor {
        let vd = MTLVertexDescriptor()
        vd.attributes[0].format = .float3
        vd.attributes[0].offset = 0
        vd.attributes[0].bufferIndex = 0
        vd.attributes[1].format = .float2
        vd.attributes[1].offset = MemoryLayout<Float>.stride * 3
        vd.attributes[1].bufferIndex = 0
        vd.attributes[2].format = .float
        vd.attributes[2].offset = MemoryLayout<Float>.stride * 5
        vd.attributes[2].bufferIndex = 0
        vd.attributes[3].format = .float
        vd.attributes[3].offset = MemoryLayout<Float>.stride * 6
        vd.attributes[3].bufferIndex = 0
        vd.attributes[4].format = .float
        vd.attributes[4].offset = MemoryLayout<Float>.stride * 7
        vd.attributes[4].bufferIndex = 0
        vd.layouts[0].stride = MemoryLayout<ProminenceVertex>.stride
        return vd
    }
}

