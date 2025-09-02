//
//  AxesRenderer.swift
//  OptiUniverse
//
//  Created by max on 05.08.2025.
//

import MetalKit

final class AxesRenderer {
    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let vertexBuffer: MTLBuffer

    init(device: MTLDevice) {
        self.device = device
        self.pipelineState = AxesRenderer.makePipelineState(device: device)
        self.vertexBuffer = AxesRenderer.makeVertexBuffer(device: device)
    }

    private static func makePipelineState(device: MTLDevice) -> MTLRenderPipelineState {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to makeDefaultLibrary")
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = library.makeFunction(name: "axes_vertex")
        pipelineDescriptor.fragmentFunction = library.makeFunction(name: "axes_fragment")
        pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba16Float
        pipelineDescriptor.sampleCount = 4
        pipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

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

    func renderAxes(with renderEncoder: MTLRenderCommandEncoder,
                    modelMatrix: float4x4,
                    viewMatrix: float4x4,
                    projectionMatrix: float4x4) {
        // Set pipeline state for lines
        renderEncoder.setRenderPipelineState(pipelineState)

        // Set prebuilt vertex buffer
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)

        // Set transformation matrix (MVP)
        var mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        renderEncoder.setVertexBytes(&mvpMatrix,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 1)

        // Draw as lines (not triangles)
        renderEncoder.drawPrimitives(type: .line,
                                     vertexStart: 0,
                                     vertexCount: 6) // 2 points per line × 3 axes = 6 vertices
    }

    private static func makeVertexBuffer(device: MTLDevice) -> MTLBuffer {
        // Define axis vertices (position + color)
        // Format: [x, y, z, r, g, b]
        let axisLength: Float = 10
        let vertices: [Float] = [
            // X axis (red)
            0, 0, 0,   1, 0, 0,
            axisLength, 0, 0,  1, 0, 0,

            // Y axis (green)
            0, 0, 0,   0, 1, 0,
            0, axisLength, 0,  0, 1, 0,

            // Z axis (blue)
            0, 0, 0,   0, 0, 1,
            0, 0, axisLength,  0, 0, 1
        ]

        return device.makeBuffer(bytes: vertices,
                                  length: vertices.count * MemoryLayout<Float>.stride,
                                  options: [])!
    }
}
