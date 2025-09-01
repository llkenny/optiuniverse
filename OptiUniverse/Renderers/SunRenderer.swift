//
//  SunRenderer.swift
//  OptiUniverse
//
//  Created by max on 01.09.2025.
//

import MetalKit
import simd
import ModelIO

struct SunUniforms {
    var mvp: simd_float4x4
    var time: Float
    var radius: Float
    var granulationScale: Float
    var flow: Float
    var limbU: Float
    var brightness: Float
    var coronaStrength: Float
    var flowStrength: Float
    var flowScale: Float
}

final class SunRenderer: NSObject {
    
    private let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipelineSun: MTLRenderPipelineState
    private let pipelineCorona: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private var sunMesh: MTKMesh
    private var coronaMesh: MTKMesh
    private var startTime = CACurrentMediaTime()
    
    private var sceneTarget: MTLTexture!
    private var brightTarget: MTLTexture!
    private var blurTemp: MTLTexture!
    private var blurFinal: MTLTexture!
    private var sceneDepth: MTLTexture!
    
    private var pipeBright: MTLRenderPipelineState!
    private var pipeBlurH: MTLRenderPipelineState!
    private var pipeBlurV: MTLRenderPipelineState!
    private var pipeComposite: MTLRenderPipelineState!
    
    struct BloomUniforms { var texelSize: SIMD2<Float>; var threshold: Float; var intensity: Float }
    private var bloom = BloomUniforms(texelSize: .zero, threshold: 1.0, intensity: 0.85)

    
    init?(mtkView: MTKView) {
        guard let device = mtkView.device ?? MTLCreateSystemDefaultDevice(),
              let queue  = device.makeCommandQueue()
        else { return nil }
        self.device = device
        self.queue = queue
        
        let drawableFormat = mtkView.colorPixelFormat           // e.g. .bgra8Unorm_srgb
        let depthFormat = mtkView.depthStencilPixelFormat
        let hdrFormat: MTLPixelFormat = .rgba16Float            // for offscreen targets
        
        // Library & pipelines
        let library = try! device.makeDefaultLibrary(bundle: .main)
        let mdlVertexDesc = makeModelIOVertexDescriptor()
        let mtlVertexDesc = MTKMetalVertexDescriptorFromModelIO(mdlVertexDesc)!
        
        func makeSunPipeline(library: MTLLibrary, format: MTLPixelFormat) throws -> MTLRenderPipelineState {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction   = library.makeFunction(name: "vertex_sun")
            d.fragmentFunction = library.makeFunction(name: "fragment_sun")
            d.vertexDescriptor = mtlVertexDesc // from your MDL→MTL conversion
            d.colorAttachments[0].pixelFormat = format            // << use hdrFormat here
            d.depthAttachmentPixelFormat = .depth32Float
            return try device.makeRenderPipelineState(descriptor: d)
        }
        
        func makeCoronaPipeline(library: MTLLibrary, format: MTLPixelFormat) throws -> MTLRenderPipelineState {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction   = library.makeFunction(name: "vertex_sun")
            d.fragmentFunction = library.makeFunction(name: "fragment_corona")
            d.vertexDescriptor = mtlVertexDesc
            d.colorAttachments[0].pixelFormat = format            // << hdrFormat
            d.depthAttachmentPixelFormat = .depth32Float
            let ca = d.colorAttachments[0]!
            ca.isBlendingEnabled = true
            ca.rgbBlendOperation = .add
            ca.alphaBlendOperation = .add
            ca.sourceRGBBlendFactor = .one
            ca.sourceAlphaBlendFactor = .one
            ca.destinationRGBBlendFactor = .one
            ca.destinationAlphaBlendFactor = .one
            return try device.makeRenderPipelineState(descriptor: d)
        }
        
        pipelineSun    = try! makeSunPipeline(library: library, format: hdrFormat)
        pipelineCorona = try! makeCoronaPipeline(library: library, format: hdrFormat)
        
        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less
        depthDesc.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depthDesc)!
        
        // Meshes
        func makeSphere(radius: Float, device: MTLDevice) -> MTKMesh {
            let allocator = MTKMeshBufferAllocator(device: device)
            let mdlDescriptor = makeModelIOVertexDescriptor()
            let mdl = MDLMesh(
                sphereWithExtent: SIMD3<Float>(repeating: radius),
                segments: SIMD2<UInt32>(200, 200),
                inwardNormals: false,
                geometryType: .triangles,
                allocator: allocator
            )
            // Apply our interleaved descriptor to the generated mesh
            mdl.vertexDescriptor = mdlDescriptor
            return try! MTKMesh(mesh: mdl, device: device)
        }
        sunMesh    = makeSphere(radius: 1.0,  device: device)
        coronaMesh = makeSphere(radius: 1.03, device: device)
        
        super.init()
        
        func makePP(_ frag: String,
                    format: MTLPixelFormat,
                    depth: MTLPixelFormat = .invalid) throws -> MTLRenderPipelineState {
            let d = MTLRenderPipelineDescriptor()
            d.vertexFunction = library.makeFunction(name: "vs_fullscreen")
            d.fragmentFunction = library.makeFunction(name: frag)
            d.colorAttachments[0].pixelFormat = format
            d.depthAttachmentPixelFormat = depth
            return try device.makeRenderPipelineState(descriptor: d)
        }
        
        // Offscreen passes (HDR)
        pipeBright = try! makePP("ps_brightpass", format: hdrFormat)
        pipeBlurH  = try! makePP("ps_blur_h",      format: hdrFormat)
        pipeBlurV  = try! makePP("ps_blur_v",      format: hdrFormat)
        
        // Final composite to the screen (drawable format)
        pipeComposite = try! makePP("ps_composite",
                                   format: drawableFormat,
                                   depth: depthFormat)
        
        // Ensure targets exist initially
        reshapeTargets(for: mtkView.drawableSize, device: device)
    }
    
    private func makeMVP(viewMatrix: float4x4, projectionMatrix: float4x4) -> float4x4 {
        let model = float4x4(rotationY: Float(CACurrentMediaTime().truncatingRemainder(dividingBy: .pi*2)) * 0.015)
        return projectionMatrix * viewMatrix * model
    }
    
    func draw(view: MTKView,
              viewMatrix: float4x4,
              projectionMatrix: float4x4,
              commandBuffer: MTLCommandBuffer) {
        
        let t = Float(CACurrentMediaTime() - startTime)
        var uni = SunUniforms(
            mvp: makeMVP(viewMatrix: viewMatrix, projectionMatrix: projectionMatrix),
            time: t,
            radius: 1.0,
            granulationScale: 40,
            flow: 0.06,
            limbU: 0.6,
            brightness: 1.2,
            coronaStrength: 1.2,
            flowStrength: 0.7,
            flowScale: 0.7
        )
//        
//        // Sun (photosphere)
//        renderEncoder.setRenderPipelineState(pipelineSun)
//        draw(mesh: sunMesh, encoder: renderEncoder, uniforms: &uni)
//        
//        // Corona (additive shell)
//        renderEncoder.setRenderPipelineState(pipelineCorona)
//        draw(mesh: coronaMesh, encoder: renderEncoder, uniforms: &uni)
        
        // Pass 0: scene
        let sceneRPD = MTLRenderPassDescriptor()
        sceneRPD.colorAttachments[0].texture = sceneTarget
        sceneRPD.colorAttachments[0].loadAction = .clear
        sceneRPD.colorAttachments[0].storeAction = .store
        sceneRPD.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,1)
        sceneRPD.depthAttachment.texture = sceneDepth
        sceneRPD.depthAttachment.loadAction = .clear
        sceneRPD.depthAttachment.storeAction = .dontCare
        sceneRPD.depthAttachment.clearDepth = 1.0
        
        let enc0 = commandBuffer.makeRenderCommandEncoder(descriptor: sceneRPD)!
        enc0.setDepthStencilState(depthState)
        // draw sun
        enc0.setRenderPipelineState(pipelineSun)
        draw(mesh: sunMesh, encoder: enc0, uniforms: &uni)
        enc0.setRenderPipelineState(pipelineCorona)
        draw(mesh: coronaMesh, encoder: enc0, uniforms: &uni)
        enc0.endEncoding()
        
        func blitPass(dst: MTLTexture, pipeline: MTLRenderPipelineState, set: (MTLRenderCommandEncoder)->Void) {
            let r = MTLRenderPassDescriptor()
            r.colorAttachments[0].texture = dst
            r.colorAttachments[0].loadAction = .clear
            r.colorAttachments[0].storeAction = .store
            r.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,1)
            let e = commandBuffer.makeRenderCommandEncoder(descriptor: r)!
            e.setRenderPipelineState(pipeline)
            set(e)
            e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            e.endEncoding()
        }
        
        blitPass(dst: brightTarget, pipeline: pipeBright) { e in
            e.setFragmentTexture(sceneTarget, index: 0)
            var bu = bloom
            e.setFragmentBytes(&bu, length: MemoryLayout<BloomUniforms>.stride, index: 0)
        }
        
        blitPass(dst: blurTemp, pipeline: pipeBlurH) { e in
            e.setFragmentTexture(brightTarget, index: 0)
            var bu = bloom
            e.setFragmentBytes(&bu, length: MemoryLayout<BloomUniforms>.stride, index: 0)
        }
        
        blitPass(dst: blurFinal, pipeline: pipeBlurV) { e in
            e.setFragmentTexture(blurTemp, index: 0)
            var bu = bloom
            e.setFragmentBytes(&bu, length: MemoryLayout<BloomUniforms>.stride, index: 0)
        }
        
        let finalRPD = view.currentRenderPassDescriptor!
        let e = commandBuffer.makeRenderCommandEncoder(descriptor: finalRPD)!
        e.setRenderPipelineState(pipeComposite)
        e.setFragmentTexture(sceneTarget, index: 0)
        e.setFragmentTexture(blurFinal, index: 1)
        var bu = bloom
        e.setFragmentBytes(&bu, length: MemoryLayout<BloomUniforms>.stride, index: 0)
        e.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        e.endEncoding()
    }
    
    private func draw(mesh: MTKMesh, encoder enc: MTLRenderCommandEncoder, uniforms: inout SunUniforms) {
        enc.setVertexBytes(&uniforms, length: MemoryLayout<SunUniforms>.stride, index: 1)
        enc.setFragmentBytes(&uniforms, length: MemoryLayout<SunUniforms>.stride, index: 1)
        
        let vb = mesh.vertexBuffers[0]
        enc.setVertexBuffer(vb.buffer, offset: vb.offset, index: 0)
        
        for sub in mesh.submeshes {
            enc.drawIndexedPrimitives(type: .triangle,
                                      indexCount: sub.indexCount,
                                      indexType: sub.indexType,
                                      indexBuffer: sub.indexBuffer.buffer,
                                      indexBufferOffset: sub.indexBuffer.offset)
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        reshapeTargets(for: view.drawableSize, device: device)
    }
    
    private func reshapeTargets(for size: CGSize, device: MTLDevice) {
        let w = max(1, Int(size.width))
        let h = max(1, Int(size.height))
        func makeTex(_ format: MTLPixelFormat) -> MTLTexture {
            let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: w, height: h, mipmapped: false)
            desc.usage = [.renderTarget, .shaderRead, .shaderWrite]
            desc.storageMode = .private
            return device.makeTexture(descriptor: desc)!
        }
        // Use HDR-ish format to keep highlights
        sceneTarget = makeTex(.rgba16Float)
        brightTarget = makeTex(.rgba16Float)
        blurTemp = makeTex(.rgba16Float)
        blurFinal = makeTex(.rgba16Float)

        let depthDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float, width: w, height: h, mipmapped: false)
        depthDesc.usage = [.renderTarget]
        depthDesc.storageMode = .private
        sceneDepth = device.makeTexture(descriptor: depthDesc)!

        bloom.texelSize = SIMD2<Float>(1.0/Float(w), 1.0/Float(h))
    }
}

private extension float4x4 {
    init(rotationY r: Float) {
        self = matrix_identity_float4x4
        columns.0 = [ cos(r), 0,  sin(r), 0]
        columns.2 = [-sin(r), 0,  cos(r), 0]
    }
}

enum VertexAttribute: Int {
    case position = 0, normal = 1, uv = 2
}

func makeModelIOVertexDescriptor() -> MDLVertexDescriptor {
    let v = MDLVertexDescriptor()
    // Interleaved layout: pos(float3) | nrm(float3) | uv(float2)
    v.attributes[VertexAttribute.position.rawValue] = MDLVertexAttribute(
        name: MDLVertexAttributePosition, format: .float3, offset: 0, bufferIndex: 0
    )
    v.attributes[VertexAttribute.normal.rawValue] = MDLVertexAttribute(
        name: MDLVertexAttributeNormal, format: .float3, offset: 12, bufferIndex: 0
    )
    v.attributes[VertexAttribute.uv.rawValue] = MDLVertexAttribute(
        name: MDLVertexAttributeTextureCoordinate, format: .float2, offset: 24, bufferIndex: 0
    )
    v.layouts[0] = MDLVertexBufferLayout(stride: 32)
    return v
}
