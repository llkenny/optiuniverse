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
    
    init?(mtkView: MTKView) {
        guard let device = mtkView.device ?? MTLCreateSystemDefaultDevice(),
              let queue  = device.makeCommandQueue()
        else { return nil }
        self.device = device
        self.queue = queue
        
//        mtkView.depthStencilPixelFormat = .depth32Float
//        mtkView.colorPixelFormat = .bgra8Unorm_srgb
        
        // Library & pipelines
        let library = try! device.makeDefaultLibrary(bundle: .main)
        let mdlVertexDesc = makeModelIOVertexDescriptor()
        let mtlVertexDesc = MTKMetalVertexDescriptorFromModelIO(mdlVertexDesc)!
        
        let sunDesc = MTLRenderPipelineDescriptor()
        sunDesc.vertexFunction   = library.makeFunction(name: "vertex_sun")
        sunDesc.fragmentFunction = library.makeFunction(name: "fragment_sun")
        sunDesc.vertexDescriptor = mtlVertexDesc
        sunDesc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        sunDesc.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        pipelineSun = try! device.makeRenderPipelineState(descriptor: sunDesc)
        
        let coronaDesc = MTLRenderPipelineDescriptor()
        coronaDesc.vertexFunction   = library.makeFunction(name: "vertex_sun")
        coronaDesc.fragmentFunction = library.makeFunction(name: "fragment_corona")
        coronaDesc.vertexDescriptor = mtlVertexDesc
        coronaDesc.colorAttachments[0].pixelFormat = mtkView.colorPixelFormat
        coronaDesc.depthAttachmentPixelFormat = mtkView.depthStencilPixelFormat
        let ca = coronaDesc.colorAttachments[0]!
        ca.isBlendingEnabled = true
        ca.rgbBlendOperation = .add
        ca.alphaBlendOperation = .add
        ca.sourceRGBBlendFactor = .one
        ca.sourceAlphaBlendFactor = .one
        ca.destinationRGBBlendFactor = .one
        ca.destinationAlphaBlendFactor = .one
        pipelineCorona = try! device.makeRenderPipelineState(descriptor: coronaDesc)
        
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
    }
    
    private func makeMVP(viewMatrix: float4x4, projectionMatrix: float4x4) -> float4x4 {
        let model = float4x4(rotationY: Float(CACurrentMediaTime().truncatingRemainder(dividingBy: .pi*2)) * 0.015)
        return projectionMatrix * viewMatrix * model
    }
    
    func draw(viewMatrix: float4x4,
              projectionMatrix: float4x4,
              renderEncoder: MTLRenderCommandEncoder) {
        
        let t = Float(CACurrentMediaTime() - startTime)
        var uni = SunUniforms(
            mvp: makeMVP(viewMatrix: viewMatrix, projectionMatrix: projectionMatrix),
            time: t,
            radius: 1.0,
            granulationScale: 40,
            flow: 0.06,
            limbU: 0.6,
            brightness: 1.2,
            coronaStrength: 1.2
        )
        
        // Sun (photosphere)
        renderEncoder.setRenderPipelineState(pipelineSun)
        draw(mesh: sunMesh, encoder: renderEncoder, uniforms: &uni)
        
        // Corona (additive shell)
        renderEncoder.setRenderPipelineState(pipelineCorona)
        draw(mesh: coronaMesh, encoder: renderEncoder, uniforms: &uni)
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
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
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
