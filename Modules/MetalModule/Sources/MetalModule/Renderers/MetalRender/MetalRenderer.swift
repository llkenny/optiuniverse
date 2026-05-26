//
//  MetalRenderer.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import Foundation
import MetalKit
import os
import QuartzCore
import simd

@MainActor
protocol PlanetLabelDelegate: AnyObject {
    /// Updates label positions in screen space for each planet.
    func updatePlanetLabels(_ positions: [String: SIMD2<Float>])
}

// swiftlint:disable type_body_length file_length
@MainActor
final class MetalRenderer: NSObject, MTKViewDelegate {
    enum PostFXStyle: UInt32 {
        case standard = 0
        case dreamy = 1
    }

    private let projectionMatrixLogger = MatrixChangeLogger(
        logger: Logger(subsystem: "com.OptiUniverse.MetalRenderer",
                       category: "projectionMatrix"),
        caption: "Projection Matrix update:",
        queueLabel: "com.OptiUniverse.MetalRenderer.projectionMatrixLogging"
    )
    private let viewMatrixLogger = MatrixChangeLogger(
        logger: Logger(subsystem: "com.OptiUniverse.MetalRenderer",
                       category: "viewMatrix"),
        caption: "View Matrix update:",
        queueLabel: "com.OptiUniverse.MetalRenderer.viewMatrixLogging"
    )

    private let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let planetsRenderer: PlanetsRendererProtocol
    let starsRenderer: StarsRenderer
    let transferOrbitRenderer: TransferOrbitRenderer
    let routeRenderer: RouteRenderer
    let snapshotProvider: SnapshotProvider
    let navigationController: NavigationController
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

    private(set) unowned var cameraState: CameraState // The renderer must not exists without the camera state

    var followingPlanetName: String? = "Sun"
    var pendingFollowPlanetName: String?
    var pendingSelectedPlanetName: String?
    var activeTransferDestinationName: String?
    var activeTransferOrbit: HohmannTransferOrbit?
    var cameraTransition: CameraTransition?

    let planets: [Planet]

    var viewMatrix: float4x4 {
        didSet {
            viewMatrixLogger.logChange(from: oldValue, to: viewMatrix)
        }
    }
    private(set) var projectionMatrix: float4x4 {
        didSet {
            projectionMatrixLogger.logChange(from: oldValue, to: projectionMatrix)
        }
    }
    var isTrajectoryModeActive: Bool {
        activeTransferOrbit != nil ||
        navigationController.isNavigationActive
    }

    init?(metalView: MTKView,
          device: MTLDevice,
          commandQueue: MTLCommandQueue,
          cameraState: CameraState,
          planets: [Planet],
          snapshotProvider: SnapshotProvider,
          navigationController: NavigationController) {

        self.metalView = metalView
        self.cameraState = cameraState
        self.snapshotProvider = snapshotProvider
        self.navigationController = navigationController

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

        viewMatrix = matrix_identity_float4x4
        projectionMatrix = matrix_identity_float4x4

        super.init()
        prepare(viewSampleCount: viewSampleCount)
    }

    func setup(_ cameraState: CameraState) {
        self.cameraState = cameraState
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
        guard let hdrTexture,
              let msaaColorTexture,
              let depthTexture,
              let postfxMsaaTexture,
              let drawable = view.currentDrawable else {
            return
        }

        // Advance simulation time and update camera before rendering so that
        // the view matches the planets' latest positions within the same frame.
        let delta = planetsRenderer.advanceTime()
        snapshotProvider.requestPreparation(simulationTime: planetsRenderer.currentTime)
        let snapshot = snapshotProvider.latestSnapshot

        // TODO: Get data from SnapshotProvider
        update(snapshot: snapshot)
        let navigationCameraUpdate = navigationController.update(snapshot: snapshot,
                                                                  delta: delta)
        updateCamera(snapshot: snapshot,
                     delta: delta,
                     navigationCameraUpdate: navigationCameraUpdate)

        do {
            try drawFirstPass(msaaColorTexture: msaaColorTexture,
                              hdrTexture: hdrTexture,
                              depthTexture: depthTexture,
                              snapshot: snapshot,
                              routes: SceneRouteRenderState(
                                transferOrbit: activeTransferOrbit,
                                navigation: navigationController.routeRenderState
                              ))
            drawSecondPass(postfxMsaaTexture: postfxMsaaTexture,
                           drawable: drawable,
                           hdrTexture: hdrTexture)
        } catch {
            // Just skip — possible due transient Metal resource failures
        }
    }

    private func update(snapshot: PreparedRenderSnapshot?) {
        guard let snapshot else { return }

        if let name = pendingSelectedPlanetName,
                  applySelectedPlanet(named: name, snapshot: snapshot) {
            pendingSelectedPlanetName = nil
        } else {
            updateActiveTransferOrbit(snapshot: snapshot)
        }

        if let name = pendingFollowPlanetName,
           startFollowAnimation(named: name, snapshot: snapshot) {
            pendingFollowPlanetName = nil
        }
    }

    private func updateCamera(snapshot: PreparedRenderSnapshot?,
                              delta: Float,
                              navigationCameraUpdate: NavigationCameraUpdate) {
        switch navigationCameraUpdate {
        case .customLookAt, .noCameraChange:
            updateProjectionMatrix()
            return
        case .standardCameraState:
            updateCamera()
            return
        case .inactive:
            break
        }

        if cameraTransition != nil {
            updateCameraTransition(snapshot: snapshot,
                                   delta: delta)
        } else if activeTransferOrbit != nil, // 4
                  !navigationController.isNavigationActive {
            // Removing this breaks the pan gesture for the trajectory mode
            return
        } else if let name = followingPlanetName, // 5
                  let position = snapshot?.worldPosition(ofPlanetNamed: name) {
            cameraState.set(cameraTarget: position)
            updateCamera()
        }
    }

    func updateProjectionMatrix() {
        let aspect = Float(metalView.bounds.width / metalView.bounds.height)
        projectionMatrix = float4x4.perspective(
            fov: CameraFit.verticalFieldOfView,
            aspect: aspect,
            near: nearPlaneDistance(),
            far: farPlaneDistance()
        )
    }

    /// Starts following the planet with the given name.
    /// The camera moves smoothly to the planet's position and adjusts
    /// distance based on the planet's radius.
    func followPlanet(named name: String) {
        followPlanet(named: name,
                     cancelsNavigation: true)
    }

    func followNavigationDestination(named name: String) {
        followPlanet(named: name,
                     cancelsNavigation: false)
    }

    private func followPlanet(named name: String,
                              cancelsNavigation: Bool) {
        clearTransferOrbit()
        if cancelsNavigation {
            navigationController.cancelNavigation(followDestination: false)
        }
        followingPlanetName = name

        guard let snapshot = snapshotProvider.latestSnapshot,
              startFollowAnimation(named: name, snapshot: snapshot) else {
            pendingFollowPlanetName = name
            cameraTransition = nil
            return
        }

        pendingFollowPlanetName = nil
    }

    func showTransferOrbit(to name: String) {
        navigationController.cancelNavigation(followDestination: false)
        guard let snapshot = snapshotProvider.latestSnapshot,
              applySelectedPlanet(named: name, snapshot: snapshot) else {
            pendingSelectedPlanetName = name
            cameraTransition = nil
            return
        }
    }

    private func applySelectedPlanet(named name: String,
                                     snapshot: PreparedRenderSnapshot) -> Bool {
        guard let transferOrbit = makeTransferOrbit(destinationName: name,
                                                    snapshot: snapshot) else {
            clearTransferOrbit()
            followingPlanetName = name
            pendingFollowPlanetName = nil
            return startFollowAnimation(named: name, snapshot: snapshot)
        }

        activeTransferDestinationName = name
        activeTransferOrbit = transferOrbit
        followingPlanetName = "Earth"
        pendingFollowPlanetName = nil
        startTransferOverviewAnimation(transferOrbit: transferOrbit,
                                       snapshot: snapshot)
        return true
    }

    private func updateActiveTransferOrbit(snapshot: PreparedRenderSnapshot) {
        guard let activeTransferDestinationName else { return }

        guard let transferOrbit = makeTransferOrbit(destinationName: activeTransferDestinationName,
                                                    snapshot: snapshot) else {
            clearTransferOrbit()
            return
        }

        activeTransferOrbit = transferOrbit
    }

    func makeTransferOrbit(destinationName: String,
                           snapshot: PreparedRenderSnapshot) -> HohmannTransferOrbit? {
        guard let sunPosition = snapshot.worldPosition(ofPlanetNamed: "Sun"),
              let earthPosition = snapshot.worldPosition(ofPlanetNamed: "Earth") else {
            return nil
        }

        return HohmannTransferOrbit.make(destinationName: destinationName,
                                         planets: planets,
                                         earthSunDirection: earthPosition - sunPosition,
                                         sunPosition: sunPosition)
    }

    func clearTransferOrbit() {
        pendingSelectedPlanetName = nil
        activeTransferDestinationName = nil
        activeTransferOrbit = nil
    }

    private func startTransferOverviewAnimation(transferOrbit: HohmannTransferOrbit,
                                                snapshot: PreparedRenderSnapshot) {
        guard let framing = earthCenteredTransferFraming(transferOrbit: transferOrbit,
                                                         snapshot: snapshot) else {
            return
        }

        cameraTransition = CameraTransition(
            start: cameraState.currentCameraTransitionFrame,
            destination: .fixed(target: framing.center,
                                distance: distanceToFitPlanet(radius: framing.radius) * 1.08),
            duration: cameraState.cameraFollowTransitionDuration
        )
    }

    private func earthCenteredTransferFraming(transferOrbit: HohmannTransferOrbit,
                                              snapshot: PreparedRenderSnapshot)
    -> (center: SIMD3<Float>, radius: Float)? {
        guard let earthPosition = snapshot.worldPosition(ofPlanetNamed: "Earth") else {
            return nil
        }

        var framingRadius: Float = 0
        func include(center: SIMD3<Float>, radius: Float) {
            framingRadius = max(framingRadius,
                                simd_distance(earthPosition, center) + max(radius, 0))
        }

        for point in transferOrbit.points {
            include(center: point, radius: 0)
        }

        include(center: transferOrbit.sunPosition,
                radius: max(transferOrbit.earthOrbitRadius,
                            transferOrbit.destinationOrbitRadius))

        for planetName in ["Sun", "Earth", transferOrbit.destinationName] {
            guard let planetPosition = snapshot.worldPosition(ofPlanetNamed: planetName) else {
                continue
            }
            include(center: planetPosition,
                    radius: snapshot.framingRadius(ofPlanetNamed: planetName) ?? 0)
        }

        guard framingRadius.isFinite else { return nil }
        return (earthPosition, max(framingRadius, 0.001))
    }

    /// Stops any active camera interpolation so direct gestures manipulate
    /// distance/orbit immediately without being overridden on the next frame.
    func beginManualCameraControl() {
        navigationController.beginManualCameraControl()
        pendingFollowPlanetName = nil
        cameraTransition = nil
    }

    func startFollowAnimation(named name: String,
                              snapshot: PreparedRenderSnapshot) -> Bool {
        guard resolvedPlanetTransitionFrame(named: name,
                                            snapshot: snapshot) != nil else {
            return false
        }

        cameraTransition = CameraTransition(
            start: cameraState.currentCameraTransitionFrame,
            destination: .planet(name: name),
            duration: cameraState.cameraFollowTransitionDuration
        )
        return true
    }

    private func updateCameraTransition(snapshot: PreparedRenderSnapshot?,
                                        delta: Float) {
        guard var transition = cameraTransition else { return }
        guard let frame = transition.advance(delta: delta, resolveDestination: { [weak self] destination in
            guard let self else { return nil }
            return self.resolveCameraTransitionDestination(destination,
                                                           snapshot: snapshot)
        }) else {
            return
        }

        cameraTransition = transition.isComplete ? nil : transition
        cameraState.set(cameraTarget: frame.target)
        cameraState.set(cameraDistance: frame.distance)
        updateCamera()
    }

    private func resolveCameraTransitionDestination(_ destination: CameraTransition.Destination,
                                                    snapshot: PreparedRenderSnapshot?)
    -> CameraTransition.Frame? {
        switch destination {
        case .planet(let name):
            guard let snapshot else { return nil }
            return resolvedPlanetTransitionFrame(named: name,
                                                 snapshot: snapshot)
        case .fixed(let target, let distance):
            return CameraTransition.Frame(target: target,
                                          distance: distance)
        }
    }

    private func resolvedPlanetTransitionFrame(named name: String,
                                               snapshot: PreparedRenderSnapshot)
    -> CameraTransition.Frame? {
        guard let position = snapshot.worldPosition(ofPlanetNamed: name),
              let framingRadius = snapshot.framingRadius(ofPlanetNamed: name) else {
            return nil
        }

        return CameraTransition.Frame(target: position,
                                      distance: distanceToFitPlanet(radius: framingRadius))
    }

    func updateCamera() {
        cameraState.checkDistance(minDistance: minimumAllowedCameraDistance())
        viewMatrix = cameraState.makeViewMatrix()
        updateProjectionMatrix()
    }

    private func minimumAllowedCameraDistance() -> Float {
        let minDistance = cameraState.minDistance

        guard let followingPlanetName,
              let framingRadius = snapshotProvider
            .latestSnapshot?
            .framingRadius(ofPlanetNamed: followingPlanetName) else {
            return minDistance
        }

        return max(minDistance, framingRadius * 1.05)
    }

    func distanceToFitPlanet(radius: Float) -> Float {
        guard radius > 0 else { return max(cameraState.cameraDistance, CameraFit.defaultNearPlane) }

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
        if let navigationNearPlaneDistance = navigationController.navigationNearPlaneDistance() {
            return navigationNearPlaneDistance
        }

        guard let followingPlanetName,
              let framingRadius = snapshotProvider
            .latestSnapshot?
            .framingRadius(ofPlanetNamed: followingPlanetName) else {
            return CameraFit.defaultNearPlane
        }

        let frontClearance = max(cameraState.cameraDistance - framingRadius, CameraFit.minimumNearPlane * 2)
        return min(CameraFit.defaultNearPlane,
                   max(CameraFit.minimumNearPlane, frontClearance * 0.5))
    }

    private func farPlaneDistance() -> Float {
        guard let snapshot = snapshotProvider.latestSnapshot else {
            return CameraFit.defaultFarPlane
        }

        if let activeTransferOrbit,
           let transferRadius = transferProjectionRadius(transferOrbit: activeTransferOrbit,
                                                         snapshot: snapshot) {
            return max(CameraFit.defaultFarPlane,
                       cameraState.cameraDistance + transferRadius * 1.15)
        }

        if let routeRadius = navigationController.routeProjectionRadius(snapshot: snapshot) {
            return max(CameraFit.defaultFarPlane,
                       cameraState.cameraDistance + routeRadius * 1.15)
        }

        return CameraFit.defaultFarPlane
    }

    private func transferProjectionRadius(transferOrbit: HohmannTransferOrbit,
                                          snapshot: PreparedRenderSnapshot) -> Float? {
        var radius: Float = 0

        func include(center: SIMD3<Float>, radius includedRadius: Float) {
            radius = max(radius,
                         simd_distance(cameraState.cameraTarget, center) + max(includedRadius, 0))
        }

        for point in transferOrbit.points {
            include(center: point, radius: 0)
        }

        include(center: transferOrbit.sunPosition,
                radius: max(transferOrbit.earthOrbitRadius,
                            transferOrbit.destinationOrbitRadius))

        for planetName in ["Sun", "Earth", transferOrbit.destinationName] {
            guard let planetPosition = snapshot.worldPosition(ofPlanetNamed: planetName) else {
                continue
            }

            include(center: planetPosition,
                    radius: snapshot.framingRadius(ofPlanetNamed: planetName) ?? 0)
        }

        guard radius.isFinite else { return nil }
        return max(radius, 0.001)
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
// swiftlint:enable type_body_length
