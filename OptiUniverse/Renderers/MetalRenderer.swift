//
//  MetalRenderer.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import MetalKit
import os
import QuartzCore
import simd

protocol PlanetLabelDelegate: AnyObject {
    /// Updates label positions in screen space for each planet.
    func updatePlanetLabels(_ positions: [String: SIMD2<Float>])
}

struct PostFXParams {
    var bloomThreshold: Float
    var bloomRadius: Float
    var lensDirtOpacity: Float
}

final class MetalRenderer: NSObject, MTKViewDelegate {
    
    private let projectionMatrixLogger = Logger(subsystem: "com.OptiUniverse.MetalRenderer", category: "projectionMatrix")
    private let viewMatrixLogger = Logger(subsystem: "com.OptiUniverse.MetalRenderer", category: "viewMatrix")
    
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let planetsRenderer: PlanetsRenderer
    private let sunRenderer: SunRenderer
    private let metalView: MTKView

    weak var labelDelegate: PlanetLabelDelegate?

    private var hdrTexture: MTLTexture?
    private var msaaColorTexture: MTLTexture?
    private var depthTexture: MTLTexture?
    private var postfxMsaaTexture: MTLTexture?
    private var postfxPipelineState: MTLRenderPipelineState!
    private var lensDirtTexture: MTLTexture?
    private var postFXParams = PostFXParams(bloomThreshold: 1.0, bloomRadius: 1.0, lensDirtOpacity: 0.0)
    
    // Orbital Camera
    // Camera state
    var cameraDistance: Float = 3
    var cameraYaw: Float = 0.0      // Horizontal rotation (radians)
    var cameraPitch: Float = 0 // .pi/4  // Vertical tilt (45° default)
    var cameraTarget = SIMD3<Float>(0, 0, 0)
    private var followingPlanetName: String?

    // Camera animation state
    private var startCameraTarget: SIMD3<Float>?
    private var endCameraTarget: SIMD3<Float>?
    private var startCameraDistance: Float?
    private var endCameraDistance: Float?
    private var cameraAnimationProgress: Float = 1
    private let cameraAnimationDuration: Float = 1.0
    
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
        planetsRenderer = PlanetsRenderer(device: device)
        sunRenderer = SunRenderer(device: device)
        
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

        postfxPipelineState = MetalRenderer.buildPostFXPipeline(device: device,
                                                                colorPixelFormat: metalView.colorPixelFormat,
                                                                depthPixelFormat: .invalid)

        let textureLoader = MTKTextureLoader(device: device)
        if let url = Bundle.main.url(forResource: "lens_dirt_1024", withExtension: "png") {
            lensDirtTexture = try? textureLoader.newTexture(URL: url,
                                                            options: [.origin: MTKTextureLoader.Origin.topLeft.rawValue])
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view size changes
        updateCamera()
        guard size.width > 0 && size.height > 0 else {
            hdrTexture = nil
            msaaColorTexture = nil
            depthTexture = nil
            postfxMsaaTexture = nil
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
        postfxMsaaTexture = MetalRenderer.makeMSAATexture(device: device,
                                                          size: size,
                                                          pixelFormat: view.colorPixelFormat,
                                                          sampleCount: sampleCount)
    }

    func draw(in view: MTKView) {
        guard let hdrTexture = hdrTexture,
              let msaaColorTexture = msaaColorTexture,
              let depthTexture = depthTexture,
              let postfxMsaaTexture = postfxMsaaTexture,
              let drawable = view.currentDrawable else {
              return
          }

        // Advance simulation time and update camera before rendering so that
        // the view matches the planets' latest positions within the same frame.
        let delta = planetsRenderer.advanceTime()
        let time = planetsRenderer.currentTime
        if cameraAnimationProgress < 1 {
            updateCameraAnimation(delta: delta)
        } else if let name = followingPlanetName,
                  let position = planetsRenderer.worldPosition(ofPlanetNamed: name) {
            cameraTarget = position
            updateCamera()
        }

        // First pass: render scene to MSAA texture and resolve to HDR texture
        guard let geometryCommandBuffer = commandQueue.makeCommandBuffer() else { return }
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

        guard let renderEncoder = geometryCommandBuffer.makeRenderCommandEncoder(descriptor: hdrDescriptor) else {
            return
        }

        // Render the Sun first so depth testing handles planet occlusion.
        sunRenderer.renderSun(with: renderEncoder,
                              time: time,
                              viewMatrix: viewMatrix,
                              projectionMatrix: projectionMatrix,
                              viewportSize: metalView.bounds.size)

        // Render the remaining planets.
        planetsRenderer.renderPlanets(with: renderEncoder,
                                      viewMatrix: viewMatrix,
                                      projectionMatrix: projectionMatrix,
                                      viewportSize: metalView.bounds.size,
                                      delta: delta)
        renderEncoder.endEncoding()

        if let blit = geometryCommandBuffer.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: hdrTexture)
            blit.endEncoding()
        }

        // Collect QA metrics and submit first pass
        QAHooks.tick(commandBuffer: geometryCommandBuffer, pass: "geometry", recordFrame: true)
        geometryCommandBuffer.commit()

        // Update any label overlays with the latest planet positions
        var positions = planetsRenderer.planetScreenPositions
        if let sunPos = sunRenderer.screenPosition {
            positions[sunRenderer.name] = sunPos
        }
        if let sunWorld = sunRenderer.worldPosition {
            planetsRenderer.planetWorldPositions[sunRenderer.name] = sunWorld
        }
        labelDelegate?.updatePlanetLabels(positions)

        // Second pass: post-process to drawable using MSAA and resolve to the drawable
        guard let postfxCommandBuffer = commandQueue.makeCommandBuffer() else { return }
        let finalDescriptor = MTLRenderPassDescriptor()
        finalDescriptor.colorAttachments[0].texture = postfxMsaaTexture
        finalDescriptor.colorAttachments[0].resolveTexture = drawable.texture
        finalDescriptor.colorAttachments[0].loadAction = .clear
        finalDescriptor.colorAttachments[0].storeAction = .multisampleResolve
        finalDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

        if let quadEncoder = postfxCommandBuffer.makeRenderCommandEncoder(descriptor: finalDescriptor) {
            quadEncoder.setRenderPipelineState(postfxPipelineState)
            quadEncoder.setFragmentTexture(hdrTexture, index: 0)
            quadEncoder.setFragmentTexture(lensDirtTexture, index: 1)
            quadEncoder.setFragmentBytes(&postFXParams, length: MemoryLayout<PostFXParams>.stride, index: 0)
            quadEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            quadEncoder.endEncoding()
        }

        QAHooks.tick(commandBuffer: postfxCommandBuffer, pass: "postfx")

        postfxCommandBuffer.present(drawable)
        postfxCommandBuffer.commit()
    }
    
    private func updateProjectionMatrix() {
        // TODO: If no zoom via fov - move to constant
        let aspect = Float(metalView.bounds.width/metalView.bounds.height)
        projectionMatrix = float4x4.perspective(
            fov: .pi/3,
            aspect: aspect,
            near: 0.1,
            far: 10000
        )
    }

    /// Starts following the planet with the given name.
    /// The camera moves smoothly to the planet's position and adjusts
    /// distance based on the planet's radius.
    func followPlanet(named name: String) {
        followingPlanetName = name
        if name == sunRenderer.name {
            startCameraTarget = cameraTarget
            endCameraTarget = sunRenderer.worldPosition ?? SIMD3<Float>(0, 0, 0)
            startCameraDistance = cameraDistance
            endCameraDistance = max(sunRenderer.radius * 5, 0.1)
            cameraAnimationProgress = 0
            return
        }

        if let position = planetsRenderer.worldPosition(ofPlanetNamed: name) {
            startCameraTarget = cameraTarget
            endCameraTarget = position
        }
        if let planet = planetsRenderer.planet(named: name) {
            startCameraDistance = cameraDistance
            endCameraDistance = max(planet.radius * 5, 0.1)
        }
        cameraAnimationProgress = 0
    }

    private func updateCameraAnimation(delta: Float) {
        guard cameraAnimationProgress < 1,
              let startTarget = startCameraTarget,
              let endTarget = endCameraTarget,
              let startDistance = startCameraDistance,
              let endDistance = endCameraDistance else { return }

        cameraAnimationProgress = min(cameraAnimationProgress + delta / cameraAnimationDuration, 1)
        let t = cameraAnimationProgress

        cameraTarget = startTarget + (endTarget - startTarget) * t
        cameraDistance = startDistance + (endDistance - startDistance) * t
        updateCamera()

        if cameraAnimationProgress >= 1 {
            startCameraTarget = nil
            endCameraTarget = nil
            startCameraDistance = nil
            endCameraDistance = nil
        }
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

    private static func buildPostFXPipeline(device: MTLDevice,
                                            colorPixelFormat: MTLPixelFormat,
                                            depthPixelFormat: MTLPixelFormat) -> MTLRenderPipelineState {
        let library = device.makeDefaultLibrary()!
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "fullscreen_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "postfx_fragment")
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
                                                                  mipmapped: true)
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
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
