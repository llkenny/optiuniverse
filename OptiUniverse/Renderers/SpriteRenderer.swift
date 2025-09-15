import MetalKit
import simd

struct SceneSprite {
    var position: SIMD3<Float>
    var size: Float
    var texture: MTLTexture
    var startTime: Float
    var duration: Float
}

final class SpriteRenderer {
    private let device: MTLDevice
    private var sprites: [SceneSprite] = []
    private var pipelineState: MTLRenderPipelineState?
    private var vertexBuffer: MTLBuffer?
    private var samplerState: MTLSamplerState?

    init(device: MTLDevice) {
        self.device = device
        buildResources()
    }

    private func buildResources() {
        struct SpriteVertex {
            var position: SIMD2<Float>
            var uv: SIMD2<Float>
        }
        let quad: [SpriteVertex] = [
            SpriteVertex(position: [-0.5, -0.5], uv: [0, 1]),
            SpriteVertex(position: [ 0.5, -0.5], uv: [1, 1]),
            SpriteVertex(position: [-0.5,  0.5], uv: [0, 0]),
            SpriteVertex(position: [ 0.5,  0.5], uv: [1, 0])
        ]
        vertexBuffer = device.makeBuffer(bytes: quad,
                                         length: MemoryLayout<SpriteVertex>.stride * quad.count,
                                         options: [])

        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        vertexDescriptor.attributes[1].format = .float2
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        vertexDescriptor.layouts[0].stride = MemoryLayout<SpriteVertex>.stride

        if let library = device.makeDefaultLibrary(),
           let vFunc = library.makeFunction(name: "sprite_vertex"),
           let fFunc = library.makeFunction(name: "sprite_fragment") {
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = vFunc
            desc.fragmentFunction = fFunc
            desc.vertexDescriptor = vertexDescriptor
            desc.colorAttachments[0].pixelFormat = .rgba16Float
            desc.colorAttachments[0].isBlendingEnabled = true
            desc.colorAttachments[0].rgbBlendOperation = .add
            desc.colorAttachments[0].alphaBlendOperation = .add
            desc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            desc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
            desc.colorAttachments[0].destinationRGBBlendFactor = .one
            desc.colorAttachments[0].destinationAlphaBlendFactor = .one
            desc.depthAttachmentPixelFormat = .depth32Float
            pipelineState = try? device.makeRenderPipelineState(descriptor: desc)
        }

        let samplerDesc = MTLSamplerDescriptor()
        samplerDesc.minFilter = .linear
        samplerDesc.magFilter = .linear
        samplerState = device.makeSamplerState(descriptor: samplerDesc)
    }

    func addSprite(texture: MTLTexture,
                   position: SIMD3<Float>,
                   size: Float,
                   startTime: Float,
                   duration: Float = 1.0) {
        let sprite = SceneSprite(position: position,
                                 size: size,
                                 texture: texture,
                                 startTime: startTime,
                                 duration: duration)
        sprites.append(sprite)
    }

    func update(time: Float) {
        sprites.removeAll { time - $0.startTime > $0.duration }
    }

    func render(with encoder: MTLRenderCommandEncoder,
                viewMatrix: float4x4,
                projectionMatrix: float4x4,
                currentTime: Float) {
        guard let pipelineState = pipelineState,
              let vertexBuffer = vertexBuffer,
              let samplerState = samplerState else { return }

        encoder.setRenderPipelineState(pipelineState)
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        encoder.setFragmentSamplerState(samplerState, index: 0)

        for sprite in sprites {
            var model = float4x4.makeTranslation(sprite.position) *
                        float4x4.makeScale(SIMD3<Float>(repeating: sprite.size))
            var mvp = projectionMatrix * viewMatrix * model
            encoder.setVertexBytes(&mvp,
                                   length: MemoryLayout<float4x4>.stride,
                                   index: 1)
            encoder.setFragmentTexture(sprite.texture, index: 0)
            encoder.drawPrimitives(type: .triangleStrip,
                                   vertexStart: 0,
                                   vertexCount: 4)
        }
    }
}
