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

// swiftlint:disable type_body_length file_length
@MainActor
final class MetalRenderer: NSObject, MTKViewDelegate {
    enum PostFXStyle: UInt32 {
        case standard = 0
        case dreamy = 1
    }

    enum CameraFit {
        static let verticalFieldOfView: Float = .pi / 3
        static let viewportFill: Float = 0.84
        static let defaultNearPlane: Float = 0.1
        static let defaultFarPlane: Float = 10000
        static let minimumNearPlane: Float = 0.0005
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
    let navigationRouteCoordinator: NavigationRouteCoordinator
    let renderPreparationPipeline: RenderPreparationPipeline
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

    // Orbital Camera
    // Camera state
    var cameraDistance: Float = 3
    var cameraTarget = SIMD3<Float>(0, 0, 0)
    var cameraPosition = SIMD3<Float>(0, 0, 0)
    var cameraUp = SIMD3<Float>(0, 1, 0)
    var cameraOffset = SIMD3<Float>(0, 0, 3)
    private var cameraOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
    var followingPlanetName: String? = "Sun"
    var pendingFollowPlanetName: String?
    var pendingSelectedPlanetName: String?
    var pendingNavigationDestinationName: String?
    var activeTransferDestinationName: String?
    var activeTransferOrbit: HohmannTransferOrbit?
    var transferCameraTargetOffset = SIMD3<Float>(repeating: 0)
    var navigationCameraFollowEnabled = true
    var navigationCameraTrailingOffset = SIMD3<Float>(0, 0, 0.18)
    var navigationArrivalRouteID: UUID?
    var navigationArrivalStartCameraPosition = SIMD3<Float>(repeating: 0)
    var navigationArrivalStartTarget = SIMD3<Float>(repeating: 0)
    var navigationArrivalTargetOffset = SIMD3<Float>(0, 0, 1)
    var navigationArrivalProgress: Float = 1
    let navigationArrivalDuration: Float = 0.9
    let navigationArrivalDistanceMultiplier: Float = 5.8

    // Camera animation state
    var startCameraTarget: SIMD3<Float>?
    var endCameraTarget: SIMD3<Float>?
    var startCameraDistance: Float?
    var endCameraDistance: Float?
    var cameraAnimationProgress: Float = 1
    private let cameraAnimationDuration: Float = 1.0

    let meshProvider: MeshProvider
    let orbitRenderHandler: OrbitRenderHandlerProtocol
    let navigationRenderHandler: NavigationRenderHandlerProtocol
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
        navigationRouteCoordinator.activeRouteForRendering != nil
    }

    init?(metalView: MTKView,
          meshProvider: MeshProvider,
          orbitRenderHandler: OrbitRenderHandlerProtocol,
          navigationRenderHandler: NavigationRenderHandlerProtocol) {
        guard let commandQueue = meshProvider.device.makeCommandQueue() else {
            return nil
        }

        self.device = meshProvider.device
        self.commandQueue = commandQueue
        self.metalView = metalView
        self.meshProvider = meshProvider
        self.orbitRenderHandler = orbitRenderHandler
        self.navigationRenderHandler = navigationRenderHandler
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .less
        depthStencilDescriptor.isDepthWriteEnabled = true
        guard let depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor) else {
            return nil
        }
        self.depthStencilState = depthStencilState
        let viewSampleCount = metalView.sampleCount > 1 ? metalView.sampleCount : 4
        let planets = SolarSystemLoader.loadPlanets(from: "planets")
        self.planets = planets
        planetsRenderer = PlanetsRenderer(device: device, sampleCount: viewSampleCount)
        starsRenderer = StarsRenderer(device: device, sampleCount: viewSampleCount)
        transferOrbitRenderer = TransferOrbitRenderer(device: device, sampleCount: viewSampleCount)
        routeRenderer = RouteRenderer(device: device, sampleCount: viewSampleCount)
        navigationRouteCoordinator = NavigationRouteCoordinator { [weak navigationRenderHandler] snapshot in
            navigationRenderHandler?.navigationSnapshot = snapshot
        }
        renderPreparationPipeline = RenderPreparationPipeline(modelLoader: meshProvider.modelLoader,
                                                              planets: planets)

        viewMatrix = matrix_identity_float4x4
        projectionMatrix = matrix_identity_float4x4

        super.init()
        prepare(viewSampleCount: viewSampleCount)
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
        renderPreparationPipeline.requestPreparation(simulationTime: planetsRenderer.currentTime)
        let snapshot = renderPreparationPipeline.latestSnapshot

        update(snapshot: snapshot)
        navigationRouteCoordinator.update()
        updateCamera(snapshot: snapshot, delta: delta)

        do {
            try drawFirstPass(msaaColorTexture: msaaColorTexture,
                              hdrTexture: hdrTexture,
                              depthTexture: depthTexture,
                              snapshot: snapshot,
                              routes: SceneRouteRenderState(
                                transferOrbit: activeTransferOrbit,
                                navigation: NavigationRouteRenderState(
                                    route: navigationRouteCoordinator.activeRouteForRendering,
                                    progress: navigationRouteCoordinator.renderProgress,
                                    elapsedTime: navigationRouteCoordinator.elapsedTime
                                )
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

        if let name = pendingNavigationDestinationName,
           applyNavigation(named: name, snapshot: snapshot) {
            pendingNavigationDestinationName = nil
        } else if let name = pendingSelectedPlanetName,
                  applySelectedPlanet(named: name, snapshot: snapshot) {
            pendingSelectedPlanetName = nil
        } else {
            updateActiveTransferOrbit(snapshot: snapshot)
        }

        if navigationRouteCoordinator.isNavigationActive,
           let activeTransferOrbit,
           let destinationPosition = snapshot.worldPosition(
            ofPlanetNamed: activeTransferOrbit.destinationName
           ) {
            navigationRouteCoordinator.refresh(using: activeTransferOrbit,
                                               destinationPosition: destinationPosition)
        }

        if let name = pendingFollowPlanetName,
           startFollowAnimation(named: name, snapshot: snapshot) {
            pendingFollowPlanetName = nil
        }
    }

    private func updateCamera(snapshot: PreparedRenderSnapshot?, delta: Float) {
        if navigationRouteCoordinator.state == .completed,
           let snapshot {
            navigationCameraFollowEnabled = true
            navigationRenderHandler.navigationCameraFollowEnabled = true
            updateNavigationArrivalCamera(snapshot: snapshot,
                                          delta: delta)
        } else if navigationRouteCoordinator.isNavigationActive,
                  navigationCameraFollowEnabled,
                  let snapshot {
            resetNavigationArrivalTransition()
            updateNavigationFollowCamera(snapshot: snapshot)
        } else if cameraAnimationProgress < 1 {
            resetNavigationArrivalTransition()
            updateCameraAnimation(delta: delta)
        } else if activeTransferOrbit != nil,
                  !navigationRouteCoordinator.isNavigationActive,
                  let earthPosition = snapshot?.worldPosition(ofPlanetNamed: "Earth") {
            resetNavigationArrivalTransition()
            cameraTarget = earthPosition + transferCameraTargetOffset
            updateCamera()
        } else if let name = followingPlanetName,
                  let position = snapshot?.worldPosition(ofPlanetNamed: name) {
            resetNavigationArrivalTransition()
            cameraTarget = position
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
        clearTransferOrbit()
        navigationRouteCoordinator.cancel()
        resetNavigationArrivalTransition()
        followingPlanetName = name

        guard let snapshot = renderPreparationPipeline.latestSnapshot,
              startFollowAnimation(named: name, snapshot: snapshot) else {
            pendingFollowPlanetName = name
            cameraAnimationProgress = 1
            return
        }

        pendingFollowPlanetName = nil
    }

    func showTransferOrbit(to name: String) {
        navigationRouteCoordinator.cancel()
        resetNavigationArrivalTransition()
        guard let snapshot = renderPreparationPipeline.latestSnapshot,
              applySelectedPlanet(named: name, snapshot: snapshot) else {
            pendingSelectedPlanetName = name
            cameraAnimationProgress = 1
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
        transferCameraTargetOffset = .zero
        publishTransferOrbitSummary(transferOrbit.summary)
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
        publishTransferOrbitSummary(transferOrbit.summary)
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
        transferCameraTargetOffset = .zero
        publishTransferOrbitSummary(nil)
    }

    func publishTransferOrbitSummary(_ summary: TransferOrbitSummary?) {
        guard orbitRenderHandler.transferOrbitSummary != summary else { return }
        orbitRenderHandler.transferOrbitSummary = summary
    }

    private func startTransferOverviewAnimation(transferOrbit: HohmannTransferOrbit,
                                                snapshot: PreparedRenderSnapshot) {
        guard let framing = earthCenteredTransferFraming(transferOrbit: transferOrbit,
                                                         snapshot: snapshot) else {
            return
        }

        startCameraTarget = cameraTarget
        endCameraTarget = framing.center
        startCameraDistance = cameraDistance
        endCameraDistance = distanceToFitPlanet(radius: framing.radius) * 1.08
        cameraAnimationProgress = 0
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
        if navigationRouteCoordinator.isNavigationActive,
           navigationCameraFollowEnabled {
            setNavigationCameraFollowEnabled(false)
        }

        if activeTransferOrbit != nil,
           let earthPosition = renderPreparationPipeline.latestSnapshot?
            .worldPosition(ofPlanetNamed: "Earth") {
            transferCameraTargetOffset = cameraTarget - earthPosition
        }

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

    func startFollowAnimation(named name: String,
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
            upVector: cameraUp
        )
        updateProjectionMatrix()
    }

    func alignCameraOrientationToCurrentLookAt() {
        guard simd_length_squared(cameraOffset) > 0.000001 else { return }

        let forward = normalize(cameraOffset)
        let fallbackUp = SIMD3<Float>(0, 1, 0)
        let upSeed = simd_length_squared(cameraUp) > 0.000001 ? normalize(cameraUp) : fallbackUp
        let candidateUp = abs(simd_dot(forward, upSeed)) > 0.94
        ? SIMD3<Float>(1, 0, 0)
        : upSeed
        let right = normalize(simd_cross(candidateUp, forward))
        let cameraUpDirection = normalize(simd_cross(forward, right))

        cameraUp = cameraUpDirection
        cameraOrientation = simd_normalize(simd_quatf(float3x3(columns: (right, cameraUpDirection, forward))))
    }

    func orbitCamera(horizontal horizontalAngle: Float, vertical verticalAngle: Float) {
        cameraOrientation = simd_normalize(cameraOrientation)

        let rightVector = normalize(cameraOrientation.act(SIMD3<Float>(1, 0, 0)))
        let upVector = normalize(cameraOrientation.act(SIMD3<Float>(0, 1, 0)))
        let horizontalRotation = simd_quatf(angle: horizontalAngle, axis: upVector)
        let verticalRotation = simd_quatf(angle: verticalAngle, axis: rightVector)

        cameraOrientation = simd_normalize(verticalRotation * horizontalRotation * cameraOrientation)
    }

    func panTrajectoryCamera(byScreenTranslation translation: CGPoint,
                             speed: Float) {
        guard isTrajectoryModeActive else { return }

        cameraOrientation = simd_normalize(cameraOrientation)

        let width = max(Float(metalView.bounds.width), 1)
        let height = max(Float(metalView.bounds.height), 1)
        let aspect = width / height
        let visibleHeight = (
            2 * max(cameraDistance, CameraFit.minimumNearPlane)
            * tan(CameraFit.verticalFieldOfView / 2)
        )
        let visibleWidth = visibleHeight * aspect
        let horizontal = Float(translation.x) / width * visibleWidth * speed
        let vertical = Float(translation.y) / height * visibleHeight * speed
        let rightVector = normalize(cameraOrientation.act(SIMD3<Float>(1, 0, 0)))
        let upVector = normalize(cameraOrientation.act(SIMD3<Float>(0, 1, 0)))

        if activeTransferOrbit != nil {
            transferCameraTargetOffset += (rightVector * horizontal) + (upVector * vertical)
        }
        cameraTarget += (rightVector * horizontal) + (upVector * vertical)
        updateCamera()
    }

    func distanceToFitPlanet(radius: Float) -> Float {
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
        if navigationRouteCoordinator.isNavigationActive,
           navigationCameraFollowEnabled,
           let route = navigationRouteCoordinator.activeRouteForRendering,
           let framingRadius = renderPreparationPipeline
            .latestSnapshot?
            .framingRadius(ofPlanetNamed: route.destinationName) {
            let frontClearance = max(cameraDistance - framingRadius, CameraFit.minimumNearPlane * 2)
            return min(CameraFit.defaultNearPlane,
                       max(CameraFit.minimumNearPlane, frontClearance * 0.5))
        }

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

    private func farPlaneDistance() -> Float {
        guard let snapshot = renderPreparationPipeline.latestSnapshot else {
            return CameraFit.defaultFarPlane
        }

        if let activeTransferOrbit,
           let transferRadius = transferProjectionRadius(transferOrbit: activeTransferOrbit,
                                                         snapshot: snapshot) {
            return max(CameraFit.defaultFarPlane,
                       cameraDistance + transferRadius * 1.15)
        }

        if let route = navigationRouteCoordinator.activeRouteForRendering,
           let routeRadius = routeProjectionRadius(route: route, snapshot: snapshot) {
            return max(CameraFit.defaultFarPlane,
                       cameraDistance + routeRadius * 1.15)
        }

        return CameraFit.defaultFarPlane
    }

    private func routeProjectionRadius(route: NavigationRoute,
                                       snapshot: PreparedRenderSnapshot) -> Float? {
        var radius: Float = 0

        func include(center: SIMD3<Float>, radius includedRadius: Float) {
            radius = max(radius,
                         simd_distance(cameraTarget, center) + max(includedRadius, 0))
        }

        for point in route.points {
            include(center: point, radius: 0)
        }

        if let sunPosition = snapshot.worldPosition(ofPlanetNamed: "Sun") {
            let routeOrbitRadius = route.points
                .map { simd_distance($0, sunPosition) }
                .max() ?? 0
            include(center: sunPosition, radius: routeOrbitRadius)
        }

        for planetName in ["Sun", route.originName, route.destinationName] {
            guard let planetPosition = snapshot.worldPosition(ofPlanetNamed: planetName) else {
                continue
            }

            include(center: planetPosition,
                    radius: snapshot.framingRadius(ofPlanetNamed: planetName) ?? 0)
        }

        guard radius.isFinite else { return nil }
        return max(radius, 0.001)
    }

    private func transferProjectionRadius(transferOrbit: HohmannTransferOrbit,
                                          snapshot: PreparedRenderSnapshot) -> Float? {
        var radius: Float = 0

        func include(center: SIMD3<Float>, radius includedRadius: Float) {
            radius = max(radius,
                         simd_distance(cameraTarget, center) + max(includedRadius, 0))
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
