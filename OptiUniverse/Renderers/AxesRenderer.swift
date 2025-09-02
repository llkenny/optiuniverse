//
//  AxesRenderer.swift
//  OptiUniverse
//
//  Created by max on 05.08.2025.
//

import MetalKit

final class AxesRenderer {
    private let device: MTLDevice
    var pipelineState: MTLRenderPipelineState!
    
    init(device: MTLDevice) {
        self.device = device
        pipelineState = setupAxesPipeline()
    }
    
    private func setupAxesPipeline() -> MTLRenderPipelineState {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to makeDefaultLibrary")
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "axes_vertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "axes_fragment")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba16Float
        pipelineDescriptor.sampleCount = 4
        
        // Important for line rendering:
        pipelineDescriptor.vertexDescriptor = {
            let descriptor = MTLVertexDescriptor()
            
            // Position (x,y,z)
            descriptor.attributes[0].format = .float3
            descriptor.attributes[0].offset = 0
            descriptor.attributes[0].bufferIndex = 0
            
            // Color (r,g,b)
            descriptor.attributes[1].format = .float3
            descriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
            descriptor.attributes[1].bufferIndex = 0
            
            descriptor.layouts[0].stride = MemoryLayout<Float>.stride * 6
            return descriptor
        }()
        
        do {
            return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Failed to create axes pipeline state: \(error)")
        }
    }
    
    func renderAxes(with renderEncoder: MTLRenderCommandEncoder) {
        // Define axis vertices (position + color)
        // Format: [x, y, z, r, g, b]
        let vertices: [Float] = [
            // X axis (red)
            0, 0, 0,   1, 0, 0,  // Start point
            10, 0, 0,  1, 0, 0,  // End point
            
            // Y axis (green)
            0, 0, 0,   0, 1, 0,  // Start point
            0, 10, 0,  0, 1, 0,  // End point
            
            // Z axis (blue)
            0, 0, 0,   0, 0, 1,  // Start point
            0, 0, 10,  0, 0, 1   // End point
        ]
        
        // Create vertex buffer
        let vertexBuffer = device.makeBuffer(bytes: vertices,
                                             length: vertices.count * MemoryLayout<Float>.stride,
                                             options: [])!
        
        // Set pipeline state for lines (make sure you have one)
        renderEncoder.setRenderPipelineState(pipelineState)
        
        // Set vertex buffer
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        // Set transformation matrix
        var matrix = matrix_identity_float4x4
        renderEncoder.setVertexBytes(&matrix,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 1)
        
        // Draw as lines (not triangles)
        renderEncoder.drawPrimitives(type: .line,
                                     vertexStart: 0,
                                     vertexCount: 6) // 2 points per line × 3 axes = 6 vertices
    }
}

