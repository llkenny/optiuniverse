//
//  MetalRenderer.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import MetalKit

final class MetalRenderer: NSObject, MTKViewDelegate {
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let axesRenderer: AxesRenderer
    private let planetsRenderer: PlanetsRenderer
    
    init?(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        axesRenderer = AxesRenderer(device: device)
        planetsRenderer = PlanetsRenderer(device: device)
        super.init()
        
        metalView.device = device
        metalView.delegate = self
//        metalView.colorPixelFormat = .bgra8Unorm_srgb
//        metalView.depthStencilPixelFormat = .depth32Float
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
        
        // Render planets
        renderEncoder.setRenderPipelineState(planetsRenderer.pipelineState)
        planetsRenderer.renderPlanets(with: renderEncoder)
        
        // Render axes
        renderEncoder.setRenderPipelineState(axesRenderer.pipelineState)
        axesRenderer.renderAxes(with: renderEncoder)
        
        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
    }
}
