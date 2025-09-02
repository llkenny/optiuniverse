//
//  MetalRenderer.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import MetalKit
import os
import QuartzCore

final class MetalRenderer: NSObject, MTKViewDelegate {
    
    private let projectionMatrixLogger = Logger(subsystem: "com.OptiUniverse.MetalRenderer", category: "projectionMatrix")
    private let viewMatrixLogger = Logger(subsystem: "com.OptiUniverse.MetalRenderer", category: "viewMatrix")
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let axesRenderer: AxesRenderer
    private let planetsRenderer: PlanetsRenderer
    private let metalView: MTKView

    private var hdrTexture: MTLTexture?
    private var msaaColorTexture: MTLTexture?
    private var depthTexture: MTLTexture?
    private var tonemapMsaaTexture: MTLTexture?
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
        metalView.sampleCount = 4
        if #available(iOS 13.0, *) {
            (metalView.layer as? CAMetalLayer)?.colorspace =
                CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        }
        metalView.depthStencilPixelFormat = .depth32Float

        tonemapPipelineState = MetalRenderer.buildTonemapPipeline(device: device,
                                                                 colorPixelFormat: metalView.colorPixelFormat,
                                                                 depthPixelFormat: .invalid)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view size changes
        updateCamera()
        guard size.width > 0 && size.height > 0 else {
            hdrTexture = nil
            msaaColorTexture = nil
            depthTexture = nil
            tonemapMsaaTexture = nil
            return
        }

        hdrTexture = MetalRenderer.makeHDRTexture(device: device, size: size)
        let sampleCount = metalView.sampleCount
        msaaColorTexture = MetalRenderer.makeMSAATexture(device: device,
                                                         size: size,
                                                         pixelFormat: .rgba16Float,
                                                         sampleCount: sampleCount)
        depthTexture = MetalRenderer.makeMSAATexture(device: device,
                                                     size: size,
                                                     pixelFormat: metalView.depthStencilPixelFormat,
                                                     sampleCount: sampleCount)
        tonemapMsaaTexture = MetalRenderer.makeMSAATexture(device: device,
                                                           size: size,
                                                           pixelFormat: view.colorPixelFormat,
                                                           sampleCount: sampleCount)
    }

    func draw(in view: MTKView) {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let hdrTexture = hdrTexture,
              let msaaColorTexture = msaaColorTexture,
              let depthTexture = depthTexture,
              let tonemapMsaaTexture = tonemapMsaaTexture,
              let drawable = view.currentDrawable else {
            return
        }

        // First pass: render scene to MSAA texture and resolve to HDR texture
        let hdrDescriptor = MTLRenderPassDescriptor()
        hdrDescriptor.colorAttachments[0].texture = msaaColorTexture
        hdrDescriptor.colorAttachments[0].resolveTexture = hdrTexture
        hdrDescriptor.colorAttachments[0].loadAction = .clear
        hdrDescriptor.colorAttachments[0].storeAction = .multisampleResolve
        hdrDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        hdrDescriptor.depthAttachment.texture = depthTexture
        hdrDescriptor.depthAttachment.loadAction = .clear
        hdrDescriptor.depthAttachment.storeAction = .dontCare
        hdrDescriptor.depthAttachment.clearDepth = 1.0

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: hdrDescriptor) else {
            return
        }

        renderEncoder.setRenderPipelineState(planetsRenderer.pipelineState)
        planetsRenderer.renderPlanets(with: renderEncoder,
                                      viewMatrix: viewMatrix,
                                      projectionMatrix: projectionMatrix)

        renderEncoder.setRenderPipelineState(axesRenderer.pipelineState)
        axesRenderer.renderAxes(with: renderEncoder,
                                modelMatrix: planetsRenderer.sunModelMatrix,
                                viewMatrix: viewMatrix,
                                projectionMatrix: projectionMatrix)
        renderEncoder.endEncoding()

        // Second pass: tone map to drawable using MSAA and resolve to the drawable
        let finalDescriptor = MTLRenderPassDescriptor()
        finalDescriptor.colorAttachments[0].texture = tonemapMsaaTexture
        finalDescriptor.colorAttachments[0].resolveTexture = drawable.texture
        finalDescriptor.colorAttachments[0].loadAction = .clear
        finalDescriptor.colorAttachments[0].storeAction = .multisampleResolve
        finalDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        if let quadEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: finalDescriptor) {
            quadEncoder.setRenderPipelineState(tonemapPipelineState)
            quadEncoder.setFragmentTexture(hdrTexture, index: 0)
            quadEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            quadEncoder.endEncoding()
        }

        commandBuffer.present(drawable)
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
                                             colorPixelFormat: MTLPixelFormat,
                                             depthPixelFormat: MTLPixelFormat) -> MTLRenderPipelineState {
        let library = device.makeDefaultLibrary()!
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "fullscreen_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "tonemap_fragment")
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.sampleCount = 4
        descriptor.depthAttachmentPixelFormat = depthPixelFormat
        return try! device.makeRenderPipelineState(descriptor: descriptor)
    }

    private static func makeHDRTexture(device: MTLDevice, size: CGSize) -> MTLTexture {
        let width = max(Int(size.width), 1)
        let height = max(Int(size.height), 1)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float,
                                                                  width: width,
                                                                  height: height,
                                                                  mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .private
        return device.makeTexture(descriptor: descriptor)!
    }

    private static func makeMSAATexture(device: MTLDevice,
                                        size: CGSize,
                                        pixelFormat: MTLPixelFormat,
                                        sampleCount: Int) -> MTLTexture {
        let width = max(Int(size.width), 1)
        let height = max(Int(size.height), 1)
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: pixelFormat,
                                                                  width: width,
                                                                  height: height,
                                                                  mipmapped: false)
        descriptor.sampleCount = sampleCount
        descriptor.textureType = .type2DMultisample
        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget]
        return device.makeTexture(descriptor: descriptor)!
    }
}
