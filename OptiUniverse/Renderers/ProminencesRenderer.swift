import Foundation
import MetalKit
import simd

struct ProminenceParams {
    var time: Float = 0
    var flipFps: Float = 16
    var cols: Int32 = 1
    var rows: Int32 = 1
    var intensity: Float = 1
    var hueShift: Float = 0
    var noiseUV: SIMD2<Float> = SIMD2<Float>(1,1)
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
    var camUp: SIMD3<Float>
}

final class ProminencesRenderer {
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let samplerState: MTLSamplerState
    private let flipbook: MTLTexture
    private let noise: MTLTexture
    private var vertexBuffer: MTLBuffer?
    private var spriteCount: Int = 0
    private var params = ProminenceParams()

    init(device: MTLDevice, sunRadius: Float) {
        self.device = device
        self.pipelineState = ProminencesRenderer.makePipelineState(device: device)
        self.samplerState = ProminencesRenderer.makeSamplerState(device: device)
        self.flipbook = ProminencesRenderer.loadTexture(device: device, name: "prominence_flipbook")
        self.noise = ProminencesRenderer.loadTexture(device: device, name: "corona_noise_512")
        loadTiming(device: device, radius: sunRadius)
    }

    private func loadTiming(device: MTLDevice, radius: Float) {
        guard let url = Bundle.main.url(forResource: "prominence_flipbook_timing", withExtension: "txt"),
              let data = try? String(contentsOf: url) else {
            return
        }
        var lines = data.split(whereSeparator: { $0.isNewline })
        guard !lines.isEmpty else { return }
        func parseFloats(_ line: Substring) -> [Float] {
            line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                .compactMap { Float($0) }
        }
        // Header
        var headerParsed = false
        var entries: [ProminenceVertex] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.first == "#" { continue }
            let nums = parseFloats(Substring(trimmed))
            if !headerParsed {
                if nums.count >= 6 {
                    params.cols = Int32(nums[1])
                    params.rows = Int32(nums[2])
                    params.flipFps = nums[3]
                    params.intensity = nums[4]
                }
                headerParsed = true
            } else {
                if nums.count >= 6 {
                    let angle = nums[0] * Float.pi / 180
                    let radiusMul = nums[1]
                    let lift = nums[2]
                    let scale = nums[3]
                    let fpsMul = nums[4]
                    let startPhase = nums[5]
                    let r = radius * radiusMul
                    let center = SIMD3<Float>(cos(angle) * r, lift * radius, sin(angle) * r)
                    let size = scale * radius
                    let corners: [SIMD2<Float>] = [
                        SIMD2<Float>(-0.5, -0.5),
                        SIMD2<Float>( 0.5, -0.5),
                        SIMD2<Float>(-0.5,  0.5),
                        SIMD2<Float>( 0.5,  0.5)
                    ]
                    for c in corners {
                        entries.append(ProminenceVertex(worldPos: center,
                                                        corner: c,
                                                        scale: size,
                                                        startPhase: startPhase,
                                                        fpsMul: fpsMul))
                    }
                }
            }
        }
        spriteCount = entries.count / 4
        let length = entries.count * MemoryLayout<ProminenceVertex>.stride
        vertexBuffer = device.makeBuffer(bytes: entries, length: length, options: [])
    }

    func render(with renderEncoder: MTLRenderCommandEncoder,
                time: Float,
                viewMatrix: float4x4,
                projectionMatrix: float4x4,
                modelMatrix: float4x4) {
        guard let vertexBuffer = vertexBuffer else { return }
        var params = self.params
        params.time = time
        let invView = viewMatrix.inverse
        var cam = CameraData(viewProj: projectionMatrix * viewMatrix,
                             camRight: SIMD3<Float>(invView.columns.0.x, invView.columns.0.y, invView.columns.0.z),
                             camUp: SIMD3<Float>(invView.columns.1.x, invView.columns.1.y, invView.columns.1.z))

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBytes(&cam, length: MemoryLayout<CameraData>.stride, index: 1)
        renderEncoder.setVertexBytes(&params, length: MemoryLayout<ProminenceParams>.stride, index: 2)
        var model = modelMatrix
        renderEncoder.setVertexBytes(&model, length: MemoryLayout<float4x4>.stride, index: 3)

        renderEncoder.setFragmentTexture(flipbook, index: 0)
        renderEncoder.setFragmentTexture(noise, index: 1)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        renderEncoder.setFragmentBytes(&params, length: MemoryLayout<ProminenceParams>.stride, index: 0)

        for i in 0..<spriteCount {
            renderEncoder.drawPrimitives(type: .triangleStrip,
                                         vertexStart: i * 4,
                                         vertexCount: 4)
        }
    }

    private static func makePipelineState(device: MTLDevice) -> MTLRenderPipelineState {
        let library = device.makeDefaultLibrary()!
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        descriptor.sampleCount = 4
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.vertexFunction = library.makeFunction(name: "prominence_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "prominence_fragment")
        let blend = descriptor.colorAttachments[0]
        blend?.isBlendingEnabled = true
        blend?.rgbBlendOperation = .add
        blend?.alphaBlendOperation = .add
        blend?.sourceRGBBlendFactor = .one
        blend?.destinationRGBBlendFactor = .one
        blend?.sourceAlphaBlendFactor = .one
        blend?.destinationAlphaBlendFactor = .one
        descriptor.vertexDescriptor = makeVertexDescriptor()
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

    private static func makeSamplerState(device: MTLDevice) -> MTLSamplerState {
        let desc = MTLSamplerDescriptor()
        desc.sAddressMode = .clampToEdge
        desc.tAddressMode = .clampToEdge
        desc.minFilter = .linear
        desc.magFilter = .linear
        desc.mipFilter = .linear
        return device.makeSamplerState(descriptor: desc)!
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

