//
//  MetalRenderer.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import MetalKit
import os

final class MetalRenderer: NSObject, MTKViewDelegate {
    enum Constants {
        static let translationSensitivity: Float = 0.01
        static let zoomSensitivity: Float = 0.5
    }
    
    private let projectionMatrixLogger = Logger(subsystem: "com.OptiUniverse.MetalRenderer", category: "projectionMatrix")
    private let viewMatrixLogger = Logger(subsystem: "com.OptiUniverse.MetalRenderer", category: "viewMatrix")
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let axesRenderer: AxesRenderer
    private let planetsRenderer: PlanetsRenderer
    private let metalView: MTKView
    
    // Camera state
    private var cameraPosition = SIMD3<Float>(0, 0, 2)
    private var cameraTarget = SIMD3<Float>(0, 0, 0)
    private var cameraUp = SIMD3<Float>(0, 1, 0)
    // Zoom
    private var zoom: Float = 1.0
    private var startScale: CGFloat = 1.0
    // Rotation
    private var rotation: Float = 0.0
    
    // Touch state
    var previousPanLocation: CGPoint = .zero
    
    private var viewMatrix: float4x4 = matrix_identity_float4x4 {
        didSet {
            viewMatrixLogger.logMatricies(matrix1: oldValue,
                                          matrix2: self.viewMatrix,
                                          caption: "View Matrix update:",
                                          level: .debug)
        }
    }
    private var projectionMatrix: float4x4 = matrix_identity_float4x4 {
        didSet {
            projectionMatrixLogger.logMatricies(matrix1: oldValue,
                                                matrix2: self.projectionMatrix,
                                                caption: "Projection Matrix update:",
                                                level: .debug)
        }
    }
    
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
        
        viewMatrix = matrix_identity_float4x4
        projectionMatrix = matrix_identity_float4x4
        
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
        cameraPosition.z += Float(scale - startScale) * Constants.zoomSensitivity
        updateViewMatrix()
        updateProjectionMatrix()
    }
    
    func handleRotationGesture(rotation: CGFloat) {
        self.rotation = Float(-rotation)
        updateViewMatrix()
        updateProjectionMatrix()
    }
    
    private func updateViewMatrix() {
        viewMatrix = matrix_identity_float4x4
        * float4x4.makeTranslation(cameraPosition)
        * float4x4.makeRotationY(rotation)
    }
    
    private func updateProjectionMatrix() {
        // TODO: If no zoom via fov - move to constant
        let aspect = Float(metalView.bounds.width/metalView.bounds.height)
        let near: Float = 0.001  // 1mm
        let far: Float = 100000.0   // 100km
        let fov: Float = .pi/3 // div by zoom for scale by fov
        projectionMatrix = float4x4(
            [1/(aspect*tan(fov/2)), 0, 0, 0],
            [0, 1/tan(fov/2), 0, 0],
            [0, 0, far/(far-near), 1],
            [0, 0, -far*near/(far-near), 0]  // Note this critical line
        )
    }
}
