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
    var style: UInt32
    var dreamyIntensity: Float
    var softFocusRadius: Float
    var hazeStrength: Float
    var saturationBoost: Float
}

// swiftlint:disable type_body_length
final class MetalRenderer: NSObject, MTKViewDelegate {
    enum PostFXStyle: UInt32 {
        case standard = 0
        case dreamy = 1
    }

    private enum CameraFit {
        static let verticalFieldOfView: Float = .pi / 3
        static let viewportFill: Float = 0.84
        static let defaultNearPlane: Float = 0.1
        static let minimumNearPlane: Float = 0.0005
    }

    private let projectionMatrixLogger = Logger(subsystem: "com.OptiUniverse.MetalRenderer", category: "projectionMatrix")
    private let viewMatrixLogger = Logger(subsystem: "com.OptiUniverse.MetalRenderer", category: "viewMatrix")

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let planetsRenderer: PlanetsRenderer
    private let renderPreparationPipeline: RenderPreparationPipeline
    private let metalView: MTKView
    private let depthStencilState: MTLDepthStencilState

    weak var labelDelegate: PlanetLabelDelegate?

    private var hdrTexture: MTLTexture?
    private var msaaColorTexture: MTLTexture?
    private var depthTexture: MTLTexture?
    private var postfxMsaaTexture: MTLTexture?
    private var postfxPipelineState: MTLRenderPipelineState!
    private var lensDirtTexture: MTLTexture?
    private var postFXParams = PostFXParams(bloomThreshold: 0.55,
                                            bloomRadius: 1.35,
                                            lensDirtOpacity: 0.2,
                                            style: PostFXStyle.standard.rawValue,
                                            dreamyIntensity: 0.0,
                                            softFocusRadius: 1.9,
                                            hazeStrength: 0.3,
                                            saturationBoost: 1.08)

    // Orbital Camera
    // Camera state
    var cameraDistance: Float = 3
    var cameraTarget = SIMD3<Float>(0, 0, 0)
    private(set) var cameraPosition = SIMD3<Float>(0, 0, 0)
    private(set) var cameraUp = SIMD3<Float>(0, 1, 0)
    private var cameraOffset = SIMD3<Float>(0, 0, 3)
    private var cameraOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    private var followingPlanetName: String? = "Sun"
    private var pendingFollowPlanetName: String?

    // Camera animation state
    private var startCameraTarget: SIMD3<Float>?
    private var endCameraTarget: SIMD3<Float>?
    private var startCameraDistance: Float?
    private var endCameraDistance: Float?
    private var cameraAnimationProgress: Float = 1
    private let cameraAnimationDuration: Float = 1.0

    private let metalProvider: MetalProvider

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

    init?(metalView: MTKView, metalProvider: MetalProvider) {
        guard let commandQueue = metalProvider.device.makeCommandQueue() else {
            return nil
        }

        self.device = metalProvider.device
        self.commandQueue = commandQueue
        self.metalView = metalView
        self.metalProvider = metalProvider
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        guard let depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor) else {
            return nil
        }
        self.depthStencilState = depthStencilState
        let viewSampleCount = metalView.sampleCount > 1 ? metalView.sampleCount : 4
        let planets = SolarSystemLoader.loadPlanets(from: "planets")
        planetsRenderer = PlanetsRenderer(device: device, sampleCount: viewSampleCount)
        renderPreparationPipeline = RenderPreparationPipeline(modelLoader: metalProvider.modelLoader,
                                                              planets: planets)

        viewMatrix = matrix_identity_float4x4
        projectionMatrix = matrix_identity_float4x4

        super.init()

        metalView.device = device
        metalView.delegate = self
        metalView.colorPixelFormat = .rgba16Float
        metalView.sampleCount = viewSampleCount
        if #available(iOS 13.0, *) {
            (metalView.layer as? CAMetalLayer)?.colorspace =
            CGColorSpace(name: CGColorSpace.extendedLinearSRGB)
        }
        metalView.depthStencilPixelFormat = .depth32Float

        postfxPipelineState = MetalRenderer.buildPostFXPipeline(device: device,
                                                                colorPixelFormat: metalView.colorPixelFormat,
                                                                depthPixelFormat: .invalid,
                                                                sampleCount: metalView.sampleCount)

        let textureLoader = MTKTextureLoader(device: device)
        if let url = Bundle.main.url(forResource: "lens_dirt_1024", withExtension: "png") {
            lensDirtTexture = try? textureLoader.newTexture(URL: url,
                                                            options: [.origin: MTKTextureLoader.Origin.topLeft.rawValue])
        }

        applyPostFXStyle(.standard)
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
        renderPreparationPipeline.requestPreparation(simulationTime: planetsRenderer.currentTime)
        let snapshot = renderPreparationPipeline.latestSnapshot

        if let name = pendingFollowPlanetName,
           let snapshot,
           startFollowAnimation(named: name, snapshot: snapshot) {
            pendingFollowPlanetName = nil
        }

        if cameraAnimationProgress < 1 {
            updateCameraAnimation(delta: delta)
        } else if let name = followingPlanetName,
                  let position = snapshot?.worldPosition(ofPlanetNamed: name) {
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
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setCullMode(.none)

        let renderOrigin = cameraTarget
        let renderViewMatrix = float4x4.lookAt(
            eye: cameraOffset,
            target: .zero,
            up: cameraUp
        )

        // Render the remaining planets.
        planetsRenderer.renderPlanets(snapshot: snapshot,
                                      with: renderEncoder,
                                      viewMatrix: renderViewMatrix,
                                      projectionMatrix: projectionMatrix,
                                      cameraPosition: cameraOffset,
                                      sceneOrigin: renderOrigin,
                                      viewportSize: metalView.bounds.size)
        renderEncoder.endEncoding()

        if let blit = geometryCommandBuffer.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: hdrTexture)
            blit.endEncoding()
        }

        geometryCommandBuffer.commit()

        // Update any label overlays with the latest planet positions
        let positions = planetsRenderer.planetScreenPositions
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

        postfxCommandBuffer.present(drawable)
        postfxCommandBuffer.commit()
    }

    private func updateProjectionMatrix() {
        let aspect = Float(metalView.bounds.width / metalView.bounds.height)
        projectionMatrix = float4x4.perspective(
            fov: CameraFit.verticalFieldOfView,
            aspect: aspect,
            near: nearPlaneDistance(),
            far: 10000
        )
    }

    /// Starts following the planet with the given name.
    /// The camera moves smoothly to the planet's position and adjusts
    /// distance based on the planet's radius.
    func followPlanet(named name: String) {
        followingPlanetName = name

        guard let snapshot = renderPreparationPipeline.latestSnapshot,
              startFollowAnimation(named: name, snapshot: snapshot) else {
            pendingFollowPlanetName = name
            cameraAnimationProgress = 1
            return
        }

        pendingFollowPlanetName = nil
    }

    /// Stops any active camera interpolation so direct gestures manipulate
    /// distance/orbit immediately without being overridden on the next frame.
    func beginManualCameraControl() {
        pendingFollowPlanetName = nil
        cameraAnimationProgress = 1
        startCameraTarget = nil
        endCameraTarget = nil
        startCameraDistance = nil
        endCameraDistance = nil
    }

    func minimumAllowedCameraDistance(baseMinimum: Float) -> Float {
        guard let followingPlanetName,
              let framingRadius = renderPreparationPipeline
            .latestSnapshot?
            .framingRadius(ofPlanetNamed: followingPlanetName) else {
            return baseMinimum
        }

        // Keep zoom outside the followed planet so pinch changes camera
        // distance instead of effectively clipping through the geometry.
        return max(baseMinimum, framingRadius * 1.05)
    }

    private func startFollowAnimation(named name: String,
                                      snapshot: PreparedRenderSnapshot) -> Bool {
        var hasPreparedFollowData = false

        if let position = snapshot.worldPosition(ofPlanetNamed: name) {
            startCameraTarget = cameraTarget
            endCameraTarget = position
            hasPreparedFollowData = true
        }

        if let framingRadius = snapshot.framingRadius(ofPlanetNamed: name) {
            startCameraDistance = cameraDistance
            endCameraDistance = distanceToFitPlanet(radius: framingRadius)
            hasPreparedFollowData = true
        }

        guard hasPreparedFollowData else { return false }

        cameraAnimationProgress = 0
        return true
    }

    private func updateCameraAnimation(delta: Float) {
        guard cameraAnimationProgress < 1,
              let startTarget = startCameraTarget,
              let endTarget = endCameraTarget,
              let startDistance = startCameraDistance,
              let endDistance = endCameraDistance else { return }

        cameraAnimationProgress = min(cameraAnimationProgress + delta / cameraAnimationDuration, 1)
        let time = cameraAnimationProgress

        cameraTarget = startTarget + (endTarget - startTarget) * time
        cameraDistance = startDistance + (endDistance - startDistance) * time
        updateCamera()

        if cameraAnimationProgress >= 1 {
            startCameraTarget = nil
            endCameraTarget = nil
            startCameraDistance = nil
            endCameraDistance = nil
        }
    }

    func updateCamera() {
        cameraOrientation = simd_normalize(cameraOrientation)

        cameraOffset = cameraOrientation.act(SIMD3<Float>(0, 0, cameraDistance))
        self.cameraPosition = cameraOffset + cameraTarget
        cameraUp = cameraOrientation.act(SIMD3<Float>(0, 1, 0))

        // 2. Update matrices
        viewMatrix = float4x4.lookAt(
            eye: cameraPosition,
            target: cameraTarget,
            up: cameraUp
        )
        updateProjectionMatrix()
    }

    func orbitCamera(horizontal horizontalAngle: Float, vertical verticalAngle: Float) {
        cameraOrientation = simd_normalize(cameraOrientation)

        let right = normalize(cameraOrientation.act(SIMD3<Float>(1, 0, 0)))
        let up = normalize(cameraOrientation.act(SIMD3<Float>(0, 1, 0)))
        let horizontalRotation = simd_quatf(angle: horizontalAngle, axis: up)
        let verticalRotation = simd_quatf(angle: verticalAngle, axis: right)

        cameraOrientation = simd_normalize(verticalRotation * horizontalRotation * cameraOrientation)
    }

    private func distanceToFitPlanet(radius: Float) -> Float {
        guard radius > 0 else { return max(cameraDistance, CameraFit.defaultNearPlane) }

        let width = max(Float(metalView.bounds.width), 1)
        let height = max(Float(metalView.bounds.height), 1)
        let aspect = width / height
        let horizontalFieldOfView = 2 * atan(tan(CameraFit.verticalFieldOfView / 2) * aspect)
        let limitingHalfFOV = min(CameraFit.verticalFieldOfView, horizontalFieldOfView) / 2
        let targetHalfAngle = atan(CameraFit.viewportFill * tan(limitingHalfFOV))
        let fittedDistance = radius / max(sin(targetHalfAngle), 0.001)

        return max(fittedDistance, radius * 1.05)
    }

    private func nearPlaneDistance() -> Float {
        guard let followingPlanetName,
              let framingRadius = renderPreparationPipeline
            .latestSnapshot?
            .framingRadius(ofPlanetNamed: followingPlanetName) else {
            return CameraFit.defaultNearPlane
        }

        let frontClearance = max(cameraDistance - framingRadius, CameraFit.minimumNearPlane * 2)
        return min(CameraFit.defaultNearPlane,
                   max(CameraFit.minimumNearPlane, frontClearance * 0.5))
    }

    func applyPostFXStyle(_ style: PostFXStyle) {
        postFXParams.style = style.rawValue

        switch style {
        case .standard:
            postFXParams.bloomThreshold = 1.0
            postFXParams.bloomRadius = 1.0
            postFXParams.lensDirtOpacity = 0.0
            postFXParams.dreamyIntensity = 0.0
            postFXParams.softFocusRadius = 0.75
            postFXParams.hazeStrength = 0.0
            postFXParams.saturationBoost = 1.0

        case .dreamy:
            postFXParams.bloomThreshold = 0.55
            postFXParams.bloomRadius = 1.35
            postFXParams.lensDirtOpacity = 0.2
            postFXParams.dreamyIntensity = 0.5
            postFXParams.softFocusRadius = 1.9
            postFXParams.hazeStrength = 0.3
            postFXParams.saturationBoost = 1.08
        }
    }

    private static func buildPostFXPipeline(device: MTLDevice,
                                            colorPixelFormat: MTLPixelFormat,
                                            depthPixelFormat: MTLPixelFormat,
                                            sampleCount: Int) -> MTLRenderPipelineState {
        let library = device.makeDefaultLibrary()!
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "fullscreen_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "postfx_fragment")
        descriptor.colorAttachments[0].pixelFormat = colorPixelFormat
        descriptor.rasterSampleCount = sampleCount
        descriptor.depthAttachmentPixelFormat = depthPixelFormat
        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("makeRenderPipelineState fatal error")
        }
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
// swiftlint:enable type_body_length
