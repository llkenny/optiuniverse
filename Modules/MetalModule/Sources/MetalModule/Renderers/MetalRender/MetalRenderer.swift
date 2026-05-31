//
//  MetalRenderer.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import Foundation
import MetalKit
import QuartzCore
import simd

@MainActor
protocol PlanetLabelDelegate: AnyObject {
    /// Updates label positions in screen space for each planet.
    func updatePlanetLabels(_ positions: [String: SIMD2<Float>])
}

@MainActor
final class MetalRenderer: NSObject, MTKViewDelegate {
    enum PostFXStyle: UInt32 {
        case standard = 0
        case dreamy = 1
    }

    private let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let planetsRenderer: PlanetsRendererProtocol
    let starsRenderer: StarsRenderer
    let transferOrbitRenderer: TransferOrbitRenderer
    let routeRenderer: RouteRenderer
    let snapshotProvider: SnapshotProvider
    let objectInfoOverlayFramingState: ObjectInfoOverlayFramingState
    let navigationController: NavigationController
    let transferOrbitController: TransferOrbitController
    let metalView: MTKView
    let depthStencilState: MTLDepthStencilState

    weak var labelDelegate: PlanetLabelDelegate?

    private var hdrTexture: MTLTexture?
    private var msaaColorTexture: MTLTexture?
    private var depthTexture: MTLTexture?
    private var postfxMsaaTexture: MTLTexture?
    private(set) var postfxPipelineState: MTLRenderPipelineState!
    private(set) var lensDirtTexture: MTLTexture?
    var postFXParams = PostFXParams(bloomThreshold: 0.55,
                                    bloomRadius: 1.35,
                                    lensDirtOpacity: 0.2,
                                    style: PostFXStyle.standard.rawValue,
                                    dreamyIntensity: 0.0,
                                    softFocusRadius: 1.9,
                                    hazeStrength: 0.3,
                                    saturationBoost: 1.08)
    var cartoonShaderIntensity: Float = 0

    let cameraCoordinator: CameraCoordinator

    let planets: [Planet]

    init?(metalView: MTKView,
          device: MTLDevice,
          commandQueue: MTLCommandQueue,
          cameraCoordinator: CameraCoordinator,
          planets: [Planet],
          snapshotProvider: SnapshotProvider,
          objectInfoOverlayFramingState: ObjectInfoOverlayFramingState,
          navigationController: NavigationController,
          transferOrbitController: TransferOrbitController) {

        self.metalView = metalView
        self.cameraCoordinator = cameraCoordinator
        self.snapshotProvider = snapshotProvider
        self.objectInfoOverlayFramingState = objectInfoOverlayFramingState
        self.navigationController = navigationController
        self.transferOrbitController = transferOrbitController

        self.device = device
        self.commandQueue = commandQueue
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        guard let depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor) else {
            return nil
        }
        self.depthStencilState = depthStencilState
        let viewSampleCount = metalView.sampleCount > 1 ? metalView.sampleCount : 4
        self.planets = planets
        planetsRenderer = PlanetsRenderer(device: device, sampleCount: viewSampleCount)
        starsRenderer = StarsRenderer(device: device, sampleCount: viewSampleCount)
        transferOrbitRenderer = TransferOrbitRenderer(device: device, sampleCount: viewSampleCount)
        routeRenderer = RouteRenderer(device: device, sampleCount: viewSampleCount)

        super.init()
        prepare(viewSampleCount: viewSampleCount)
    }

    func dismantle() {
        metalView.isPaused = true
        metalView.delegate = nil
        labelDelegate = nil
    }

    private func prepare(viewSampleCount: Int) {
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
            lensDirtTexture = try? textureLoader
                .newTexture(URL: url,
                            options: [.origin: MTKTextureLoader.Origin.topLeft.rawValue])
        }

        applyPostFXStyle(.standard)
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        // Handle view size changes
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
        guard let hdrTexture,
              let msaaColorTexture,
              let depthTexture,
              let postfxMsaaTexture,
              let drawable = view.currentDrawable else {
            return
        }

        // Advance simulation time and publish route/transfer state before camera snapshot derivation.
        let delta = planetsRenderer.advanceTime()
        snapshotProvider.requestPreparation(simulationTime: planetsRenderer.currentTime)
        let snapshot = snapshotProvider.latestSnapshot

        transferOrbitController.update(snapshot: snapshot,
                                       delta: delta)
        navigationController.update(snapshot: snapshot,
                                    delta: delta)
        let modeState = makeCameraFrameModeState()
        cameraCoordinator.updateFrameCamera(snapshot: snapshot,
                                            delta: delta,
                                            viewportSize: metalView.bounds.size,
                                            modeState: modeState)
        let objectInfoOverlayAdjustment = objectInfoOverlayFramingState.advance(delta: delta)
        let projection = makeCameraProjection(snapshot: snapshot,
                                              objectInfoOverlayAdjustment: objectInfoOverlayAdjustment)
        let cameraSnapshot = makeCameraSnapshot(snapshot: snapshot,
                                                projection: projection,
                                                modeState: modeState)

        do {
            try drawFirstPass(msaaColorTexture: msaaColorTexture,
                              hdrTexture: hdrTexture,
                              depthTexture: depthTexture,
                              state: SceneRenderState(
                                cameraSnapshot: cameraSnapshot,
                                snapshot: snapshot,
                                routes: SceneRouteRenderState(
                                    transfer: transferOrbitController.renderState,
                                    navigation: navigationController.routeRenderState
                                )
                              ))
            drawSecondPass(postfxMsaaTexture: postfxMsaaTexture,
                           drawable: drawable,
                           hdrTexture: hdrTexture)
        } catch {
            // Just skip — possible due transient Metal resource failures
        }
    }

    func farPlaneDistance() -> Float {
        return CameraFit.defaultFarPlane
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
        let library: MTLLibrary
        do {
            library = try device.makeDefaultLibrary(bundle: .module)
        } catch {
            fatalError("Failed to load Metal shader library from MetalModule bundle: \(error)")
        }
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
