//
//  MetalRenderer.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//


// MetalRenderer.swift
import MetalKit

final class MetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var pipelineState: MTLRenderPipelineState!
    private var vertexDescriptor: MTLVertexDescriptor!
    
    // Solar system data
    private var planets: [Planet] = []
    
    init?(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        super.init()
        
        metalView.device = device
        metalView.delegate = self
        metalView.colorPixelFormat = .bgra8Unorm_srgb
        metalView.depthStencilPixelFormat = .depth32Float
        
        setupPipeline()
        initializeSolarSystem()
    }
    
    private func setupPipeline() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to create Metal library")
        }
        
        // Create vertex descriptor
        vertexDescriptor = MTLVertexDescriptor()
        
        // Position attribute
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // Color attribute
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.attributes[1].bufferIndex = 0
        
        // Layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride * 2
        vertexDescriptor.layouts[0].stepRate = 1
        vertexDescriptor.layouts[0].stepFunction = .perVertex
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "vertex_main")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "fragment_main")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float
        pipelineDescriptor.vertexDescriptor = vertexDescriptor
        
        do {
            pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }
    
    private func initializeSolarSystem() {
        // Create basic solar system models
        // This would be expanded with actual planet data
        let sun = Planet(name: "Sun", radius: 1.0, distance: 0, color: .sun)
        let earth = Planet(name: "Earth", radius: 0.2, distance: 5, color: .earth)
        let mars = Planet(name: "Mars", radius: 0.15, distance: 7, color: .mars)
        
        planets = [sun, earth, mars]
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view size changes
    }
    
    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Update and render planets
        for planet in planets {
            renderPlanet(planet, with: renderEncoder)
        }
        
        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
    }
    
    private func renderPlanet(_ planet: Planet, with encoder: MTLRenderCommandEncoder) {
        // Create vertices for a simple triangle (replace with sphere data)
        let vertices: [Float] = [
            // Position         // Color
            0.0, 0.5, 0.0,     planet.color.x, planet.color.y, planet.color.z,
            -0.5, -0.5, 0.0,   planet.color.x, planet.color.y, planet.color.z,
            0.5, -0.5, 0.0,    planet.color.x, planet.color.y, planet.color.z
        ]
        
        let vertexBuffer = device.makeBuffer(bytes: vertices,
                                             length: vertices.count * MemoryLayout<Float>.stride,
                                             options: [])
        
        encoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // Simple uniform matrix (replace with proper transformation)
        var matrix = matrix_identity_float4x4
        encoder.setVertexBytes(&matrix,
                               length: MemoryLayout<float4x4>.stride,
                               index: 1)
        
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
    }
}

struct Planet {
    let name: String
    let radius: Float
    let distance: Float
    let color: SIMD3<Float>
}
