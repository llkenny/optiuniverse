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

struct ProminenceSpawn {
    var angle: Float
    var radiusMul: Float
    var lift: Float
    var scale: Float
    var fpsMul: Float
    var startPhase: Float
}

struct ProminenceVertex {
    var worldPos: SIMD3<Float>
    var corner: SIMD2<Float>
    var scale: Float
    var startPhase: Float
    var fpsMul: Float
}

struct ProminenceCamera {
    var viewProj: float4x4
    var camRight: SIMD3<Float>
    var camUp: SIMD3<Float>
}

final class ProminenceRenderer {
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private let flipbook: MTLTexture
    private let noise: MTLTexture
    private let vertexBuffer: MTLBuffer
    private let indexBuffer: MTLBuffer
    private var params: ProminenceParams

    init?(device: MTLDevice, sunRadius: Float) {
        self.device = device
        guard let library = device.makeDefaultLibrary(),
              let vf = library.makeFunction(name: "promVS"),
              let ff = library.makeFunction(name: "promFS") else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vf
        descriptor.fragmentFunction = ff
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        descriptor.sampleCount = 4
        descriptor.depthAttachmentPixelFormat = .depth32Float
        let blend = descriptor.colorAttachments[0]
        blend?.isBlendingEnabled = true
        blend?.rgbBlendOperation = .add
        blend?.alphaBlendOperation = .add
        blend?.sourceRGBBlendFactor = .one
        blend?.destinationRGBBlendFactor = .one
        blend?.sourceAlphaBlendFactor = .one
        blend?.destinationAlphaBlendFactor = .one
        pipelineState = try! device.makeRenderPipelineState(descriptor: descriptor)

        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.sAddressMode = .clampToEdge
        samplerDesc.tAddressMode = .clampToEdge
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerDesc.mipFilter = .linear
        samplerState = device.makeSamplerState(descriptor: samplerDesc)!

        flipbook = ProminenceRenderer.loadTexture(device: device, name: "prominence_flipbook")
        noise = ProminenceRenderer.loadTexture(device: device, name: "corona_noise_512")

        let (header, entries) = ProminenceRenderer.loadTimingData()
        params = ProminenceParams(time: 0,
                                  flipFps: header.fps,
                                  cols: Int32(header.cols),
                                  rows: Int32(header.rows),
                                  intensity: header.baseIntensity,
                                  hueShift: 0,
                                  noiseUV: SIMD2<Float>(2,2))

        var vertices: [ProminenceVertex] = []
        var indices: [UInt16] = []
        for (i, e) in entries.enumerated() {
            let angle = e.angle * .pi / 180
            let radius = sunRadius * e.radiusMul
            let dir = SIMD3<Float>(cos(angle), 0, sin(angle))
            let base = dir * radius + SIMD3<Float>(0, e.lift * sunRadius, 0)
            let scale = sunRadius * e.scale
            let corners = [SIMD2<Float>(-0.5, -0.5), SIMD2<Float>(0.5, -0.5), SIMD2<Float>(-0.5, 0.5), SIMD2<Float>(0.5, 0.5)]
            for c in corners {
                vertices.append(ProminenceVertex(worldPos: base,
                                                 corner: c,
                                                 scale: scale,
                                                 startPhase: e.startPhase,
                                                 fpsMul: e.fpsMul))
            }
            let baseIdx = UInt16(i*4)
            indices.append(contentsOf: [baseIdx, baseIdx+1, baseIdx+2, baseIdx+1, baseIdx+3, baseIdx+2])
        }

        vertexBuffer = device.makeBuffer(bytes: vertices,
                                         length: MemoryLayout<ProminenceVertex>.stride * vertices.count,
                                         options: [])!
        indexBuffer = device.makeBuffer(bytes: indices,
                                        length: MemoryLayout<UInt16>.stride * indices.count,
                                        options: [])!
    }

    func render(with encoder: MTLRenderCommandEncoder,
                time: Float,
                viewMatrix: float4x4,
                projectionMatrix: float4x4,
                modelMatrix: float4x4) {
        var invView = viewMatrix.inverse
        let camRight = SIMD3<Float>(invView.columns.0.x, invView.columns.0.y, invView.columns.0.z)
        let camUp = SIMD3<Float>(invView.columns.1.x, invView.columns.1.y, invView.columns.1.z)
        var camera = ProminenceCamera(viewProj: projectionMatrix * viewMatrix * modelMatrix,
                                      camRight: camRight,
                                      camUp: camUp)
        var p = params
        p.time = time

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setVertexBytes(&camera, length: MemoryLayout<ProminenceCamera>.stride, index: 0)
        encoder.setVertexBytes(&p, length: MemoryLayout<ProminenceParams>.stride, index: 1)
        encoder.setFragmentBytes(&p, length: MemoryLayout<ProminenceParams>.stride, index: 1)
        encoder.setFragmentTexture(flipbook, index: 0)
        encoder.setFragmentTexture(noise, index: 1)
        encoder.setFragmentSamplerState(samplerState, index: 0)
        encoder.drawIndexedPrimitives(type: .triangle,
                                      indexCount: indexBuffer.length / MemoryLayout<UInt16>.stride,
                                      indexType: .uint16,
                                      indexBuffer: indexBuffer,
                                      indexBufferOffset: 0)
    }

    private static func loadTimingData() -> (header: (frameCount:Int, cols:Int, rows:Int, fps:Float, baseIntensity:Float, variance:Float, seed:Int), entries:[ProminenceSpawn]) {
        guard let url = Bundle.main.url(forResource: "prominence_flipbook_timing", withExtension: "txt"),
              let data = try? String(contentsOf: url) else {
            return ((64,8,8,16,1,0,0), [])
        }
        var header: (Int,Int,Int,Float,Float,Float,Int) = (64,8,8,16,1,0,0)
        var entries: [ProminenceSpawn] = []
        for line in data.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split{ $0 == " " || $0 == "\t" }.map(String.init)
            if parts.count >= 7 && entries.isEmpty {
                header = (Int(parts[0]) ?? 64,
                          Int(parts[1]) ?? 8,
                          Int(parts[2]) ?? 8,
                          Float(parts[3]) ?? 16,
                          Float(parts[4]) ?? 1,
                          Float(parts[5]) ?? 0,
                          Int(parts[6]) ?? 0)
            } else if parts.count >= 6 {
                let spawn = ProminenceSpawn(angle: Float(parts[0]) ?? 0,
                                            radiusMul: Float(parts[1]) ?? 1,
                                            lift: Float(parts[2]) ?? 0,
                                            scale: Float(parts[3]) ?? 0.05,
                                            fpsMul: Float(parts[4]) ?? 1,
                                            startPhase: Float(parts[5]) ?? 0)
                entries.append(spawn)
            }
        }
        return (header, entries)
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
