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
final class MetalRenderer: NSObject, MTKViewDelegate {
    enum PostFXStyle: UInt32 {
        case standard = 0
        case dreamy = 1
        case filmic = 2
    }

    private let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let planetsRenderer: PlanetsRendererProtocol
    let environmentRenderer: EnvironmentRenderer
    let starsRenderer: StarsRenderer
    let transferOrbitRenderer: TransferOrbitRenderer
    let routeRenderer: RouteRenderer
    let sceneCoordinator: UniverseSceneCoordinator
    let sceneOwnershipControls: MetalSceneOwnershipControls
    let metalView: MTKView
    let depthStencilState: MTLDepthStencilState

    private var hdrTexture: MTLTexture?
    private var msaaColorTexture: MTLTexture?
    private var depthTexture: MTLTexture?
    private var postfxMsaaTexture: MTLTexture?
    private(set) var postfxPipelineState: MTLRenderPipelineState!
    var postFXParams = PostFXParams.filmic

    let planets: [Planet]

    init?(metalView: MTKView,
          device: MTLDevice,
          commandQueue: MTLCommandQueue,
          sceneOwnershipControls: MetalSceneOwnershipControls,
          planets: [Planet],
          sceneCoordinator: UniverseSceneCoordinator) {

        self.metalView = metalView
        self.sceneCoordinator = sceneCoordinator
        self.sceneOwnershipControls = sceneOwnershipControls

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
        planetsRenderer = PlanetsRenderer(device: device,
                                          sampleCount: viewSampleCount,
                                          sceneOwnershipControls: sceneOwnershipControls)
        environmentRenderer = EnvironmentRenderer(device: device, sampleCount: viewSampleCount)
        starsRenderer = StarsRenderer(device: device, sampleCount: viewSampleCount)
        transferOrbitRenderer = TransferOrbitRenderer(device: device, sampleCount: viewSampleCount)
        routeRenderer = RouteRenderer(device: device,
                                      sampleCount: viewSampleCount,
                                      sceneOwnershipControls: sceneOwnershipControls)

        super.init()
        prepare(viewSampleCount: viewSampleCount)
    }

    func dismantle() {
        metalView.isPaused = true
        metalView.delegate = nil
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

        applyPostFXStyle(.filmic)
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

        guard let frameState = sceneCoordinator.latestFrameState else { return }

        do {
            try drawFirstPass(msaaColorTexture: msaaColorTexture,
                              hdrTexture: hdrTexture,
                              depthTexture: depthTexture,
                              state: SceneRenderState(
                                simulationTime: frameState.simulationTime,
                                cameraSnapshot: frameState.cameraSnapshot,
                                snapshot: frameState.snapshot,
                                routes: frameState.routes
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
        switch style {
        case .standard:
            postFXParams = .standard

        case .dreamy:
            postFXParams = .dreamy

        case .filmic:
            postFXParams = .filmic
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
            fatalError("Failed to load Metal shader library from UniverseModule bundle: \(error)")
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
