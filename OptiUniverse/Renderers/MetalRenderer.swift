//
//  MetalRenderer.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import MetalKit

final class MetalRenderer: NSObject, MTKViewDelegate {
    enum Constants {
        static let translationSensitivity: Float = 0.01
        static let zoomSensitivity: Float = 0.5
    }
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let axesRenderer: AxesRenderer
    private let planetsRenderer: PlanetsRenderer
    private let metalView: MTKView
    
    // Camera state
    private var cameraPosition = SIMD3<Float>(0, 0, 2)
    private var cameraTarget = SIMD3<Float>(0, 0, 0)
    private var cameraUp = SIMD3<Float>(0, 1, 0)
    private var zoom: Float = 1.0
    private var startScale: CGFloat = 1.0
    
    // Touch state
    var previousPanLocation: CGPoint = .zero
    
    private var viewMatrix: float4x4 = matrix_identity_float4x4
    private var projectionMatrix: float4x4 = matrix_identity_float4x4
    
    init?(metalView: MTKView) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.metalView = metalView
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
        planetsRenderer.renderPlanets(with: renderEncoder,
                                      viewMatrix: viewMatrix,
                                      projectionMatrix: projectionMatrix)
        
        // Render axes
        renderEncoder.setRenderPipelineState(axesRenderer.pipelineState)
        axesRenderer.renderAxes(with: renderEncoder)
        
        renderEncoder.endEncoding()
        
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
    }
    
    // Gestures
    func handlePanGesture(translation: CGPoint) {
        cameraPosition.x += Float(translation.x) * Constants.translationSensitivity
        cameraPosition.y -= Float(translation.y) * Constants.translationSensitivity // Y is inverted
        updateViewMatrix()
    }
    
    func handlePinchGestureStart(scale: CGFloat) {
        startScale = scale
    }
    
    func handlePinchGestureChange(scale: CGFloat) {
        zoom *= 1 + Float(scale - startScale) * Constants.zoomSensitivity
        updateProjectionMatrix()
    }
    
    private func updateViewMatrix() {
        viewMatrix = matrix_identity_float4x4
        * float4x4.init(translation: cameraPosition)
    }
    
    private func updateProjectionMatrix() {
        projectionMatrix = matrix_identity_float4x4
        * float4x4.makeScale([zoom, zoom, zoom])
    }
}
