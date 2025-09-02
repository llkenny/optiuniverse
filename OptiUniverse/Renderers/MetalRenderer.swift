//
//  MetalRenderer.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import MetalKit
import os

final class MetalRenderer: NSObject, MTKViewDelegate {
    
    private let projectionMatrixLogger = Logger(subsystem: "com.OptiUniverse.MetalRenderer", category: "projectionMatrix")
    private let viewMatrixLogger = Logger(subsystem: "com.OptiUniverse.MetalRenderer", category: "viewMatrix")
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let axesRenderer: AxesRenderer
    private let planetsRenderer: PlanetsRenderer
    private let metalView: MTKView

    private var hdrTexture: MTLTexture!
    private var tonemapPipelineState: MTLRenderPipelineState!
    
    // Orbital Camera
    // Camera state
    var cameraDistance: Float = 3
    var cameraYaw: Float = 0.0      // Horizontal rotation (radians)
    var cameraPitch: Float = 0 // .pi/4  // Vertical tilt (45° default)
    let cameraTarget = SIMD3<Float>(0, 0, 0)
    
    private var viewMatrix: float4x4 {
        didSet {
            viewMatrixLogger.logMatricies(matrix1: oldValue,
                                          matrix2: self.viewMatrix,
                                          caption: "View Matrix update:",
                                          level: .debug)
        }
    }
    private var projectionMatrix: float4x4 {
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
        metalView.colorPixelFormat = .rgba16Float
        metalView.colorspace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        metalView.depthStencilPixelFormat = .depth32Float

        tonemapPipelineState = MetalRenderer.buildTonemapPipeline(device: device,
                                                                 pixelFormat: metalView.colorPixelFormat)
        hdrTexture = MetalRenderer.makeHDRTexture(device: device,
                                                  size: metalView.drawableSize)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view size changes
        updateCamera()
        hdrTexture = MetalRenderer.makeHDRTexture(device: device, size: size)
    }

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        // First pass: render scene to HDR texture
        let hdrDescriptor = MTLRenderPassDescriptor()
        hdrDescriptor.colorAttachments[0].texture = hdrTexture
        hdrDescriptor.colorAttachments[0].loadAction = .clear
        hdrDescriptor.colorAttachments[0].storeAction = .store
        hdrDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: hdrDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(planetsRenderer.pipelineState)
        planetsRenderer.renderPlanets(with: renderEncoder,
                                      viewMatrix: viewMatrix,
                                      projectionMatrix: projectionMatrix)

        renderEncoder.setRenderPipelineState(axesRenderer.pipelineState)
        axesRenderer.renderAxes(with: renderEncoder)
        renderEncoder.endEncoding()

        // Second pass: tone map to drawable
        if let drawable = view.currentDrawable,
           let finalDescriptor = view.currentRenderPassDescriptor,
           let quadEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: finalDescriptor) {
            quadEncoder.setRenderPipelineState(tonemapPipelineState)
            quadEncoder.setFragmentTexture(hdrTexture, index: 0)
            quadEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            quadEncoder.endEncoding()
            commandBuffer.present(drawable)
        }

        commandBuffer.commit()
    }
    
    private func updateProjectionMatrix() {
        // TODO: If no zoom via fov - move to constant
        let aspect = Float(metalView.bounds.width/metalView.bounds.height)
        projectionMatrix = float4x4.perspective(
            fov: .pi/3,
            aspect: aspect,
            near: 0.1,
            far: 1000
        )
    }
    
    func updateCamera() {
        // 1. Calculate orbit position
        let x = cameraDistance * sin(cameraYaw) * cos(cameraPitch)
        let y = cameraDistance * sin(cameraPitch)
        let z = cameraDistance * cos(cameraYaw) * cos(cameraPitch)
        
        let cameraPosition = SIMD3<Float>(x, y, z) + cameraTarget
        
        // 2. Update matrices
        viewMatrix = float4x4.lookAt(
            eye: cameraPosition,
            target: cameraTarget,
            up: SIMD3<Float>(0, 1, 0)
        )
        updateProjectionMatrix()
    }

    private static func buildTonemapPipeline(device: MTLDevice,
                                             pixelFormat: MTLPixelFormat) -> MTLRenderPipelineState {
        let library = device.makeDefaultLibrary()!
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "fullscreen_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "tonemap_fragment")
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        return try! device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeHDRTexture(device: MTLDevice, size: CGSize) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
                                                                  width: Int(size.width),
                                                                  height: Int(size.height),
                                                                  mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        return device.makeTexture(descriptor: descriptor)!
    }
}
