import CoreGraphics
import Foundation
import RealityKit
import Testing
@testable import UniverseModule

// Coordinator integration coverage intentionally keeps the complete scene contract together.
// swiftlint:disable file_length

@MainActor
@Test func sceneCoordinatorBuildsCanonicalHierarchy() throws {
    let resources = UniverseModuleResources()
    let coordinator = resources.sceneCoordinator

    #expect(coordinator.universeRoot.name == "UniverseRoot")
    #expect(coordinator.environmentRoot.parent == coordinator.universeRoot)
    #expect(coordinator.starFieldRoot.parent == coordinator.universeRoot)
    #expect(coordinator.celestialSystemRoot.parent == coordinator.universeRoot)
    #expect(coordinator.transferOrbitRoot.parent == coordinator.universeRoot)
    #expect(coordinator.navigationRouteRoot.parent == coordinator.universeRoot)
    #expect(coordinator.navigationMarkerRoot.parent == coordinator.navigationRouteRoot)
    #expect(coordinator.virtualCamera.parent == coordinator.universeRoot)
    #expect(Set(coordinator.bodyEntities.keys) == Set(resources.planets.map(\.name)))

    let sun = try #require(coordinator.bodyEntities["Sun"])
    #expect(coordinator.sunLight.name == CelestialLightingConfiguration.SunPointLight.entityName)
    #expect(coordinator.sunLight.parent == sun.orbitTransform)
    #expect(coordinator.sunLight.position == .zero)
    let sunLightComponent = try #require(
        coordinator.sunLight.components[PointLightComponent.self]
    )
    #expect(colorsAreEquivalent(
        sunLightComponent.__color,
        CelestialLightingConfiguration.SunPointLight.color
    ))
    #expect(sunLightComponent.intensity == CelestialLightingConfiguration.SunPointLight.intensity)
    #expect(
        sunLightComponent.attenuationRadius
            == CelestialLightingConfiguration.SunPointLight.attenuationRadius
    )
    #expect(
        sunLightComponent.attenuationFalloffExponent
            == CelestialLightingConfiguration.SunPointLight.attenuationFalloffExponent
    )
    #expect(descendantCount(
        named: CelestialLightingConfiguration.SunPointLight.entityName,
        in: coordinator.universeRoot
    ) == 1)

    let earth = try #require(coordinator.bodyEntities["Earth"])
    #expect(earth.bodyRoot.parent == coordinator.celestialSystemRoot)
    #expect(earth.orbitTransform.parent == earth.bodyRoot)
    #expect(earth.rotationTransform.parent == earth.orbitTransform)
    #expect(earth.visualRoot.parent == earth.rotationTransform)
}

private func colorsAreEquivalent(
    _ first: CGColor,
    _ second: CGColor,
    tolerance: CGFloat = 0.000_1
) -> Bool {
    guard let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3),
          let firstComponents = first.converted(
              to: colorSpace,
              intent: .defaultIntent,
              options: nil
          )?.components,
          let secondComponents = second.converted(
              to: colorSpace,
              intent: .defaultIntent,
              options: nil
          )?.components,
          firstComponents.count == secondComponents.count else {
        return false
    }

    return zip(firstComponents, secondComponents).allSatisfy {
        abs($0 - $1) <= tolerance
    }
}

@MainActor
private func descendantCount(named name: String, in entity: Entity) -> Int {
    let matchingEntityCount = entity.name == name ? 1 : 0
    return matchingEntityCount + entity.children.reduce(0) {
        $0 + descendantCount(named: name, in: $1)
    }
}

@MainActor
private func makeCompleteAssetFixture() -> Entity {
    let container = Entity()
    container.name = "Container"
    for name in [
        "Root",
        "MercuryLow_Mercury_0",
        "VenusLow_venus_0",
        "EarthLow_Earth_0",
        "EarthClouds_Nuvem_0",
        "MoonLow_Moon_0",
        "MarsLow_Mars_0",
        "JupiterLow_Jupiter_0",
        "JupiterLow_JupiterAtmosphere_0",
        "SaturnLow_Saturn_0",
        "UranusLow_Uranus_0",
        "PlutoLow_Pluto_0"
    ] {
        let entity = Entity()
        entity.name = name
        container.addChild(entity)
    }
    return container
}

@MainActor
private func containsModelComponent(_ entity: Entity) -> Bool {
    if entity.components[ModelComponent.self] != nil {
        return true
    }
    return entity.children.contains(where: containsModelComponent)
}

@MainActor
@Test func sunLightFollowsRebasedSunPosition() throws {
    let resources = UniverseModuleResources()
    let coordinator = resources.sceneCoordinator
    coordinator.setViewportSize(CGSize(width: 390, height: 844))
    coordinator.update(deltaTime: 0.1)
    let initialFrame = try #require(coordinator.latestFrameState)
    let sunPosition = SIMD3<Float>(100, 20, -30)
    let orbitTransformMatrix = float4x4.makeTranslation(sunPosition)
    let packet = CelestialBodySnapshot(
        planetName: "Sun",
        baseModelMatrix: orbitTransformMatrix,
        orbitTransformMatrix: orbitTransformMatrix,
        normalizedScale: 1,
        framingRadius: 1,
        surfaceRadius: 1,
        worldPosition: sunPosition
    )
    let snapshot = UniverseSceneSnapshot(frameID: 1,
                                          simulationTime: 0,
                                          planets: [packet])
    let frame = UniverseFrameState(simulationTime: 0,
                                   cameraSnapshot: initialFrame.cameraSnapshot,
                                   snapshot: snapshot,
                                   routes: initialFrame.routes)

    coordinator.apply(frameState: frame)

    #expect(coordinator.sunLight.position(relativeTo: coordinator.universeRoot)
            == sunPosition - initialFrame.cameraSnapshot.sceneOrigin)
    #expect(coordinator.sunLight.position == .zero)
}

@MainActor
@Test func sceneCoordinatorAttachesOnlyManifestBodiesWithCorrections() async throws {
    let resources = UniverseModuleResources()
    let manifest = try CelestialAssetManifestLoader.load()

    try await resources.prepare()

    #expect(resources.sceneCoordinator.realityKitOwnedBodyNames == Set(resources.planets.map(\.name)))
    #expect(resources.sceneCoordinator.isProceduralSceneContentPrepared)
    #expect(resources.sceneCoordinator.environmentRoot.children.count == 1)
    #expect(resources.sceneCoordinator.starFieldRoot.children.count == 1)
    #expect(resources.sceneCoordinator.transferOrbitRoot.children.count == 3)
    #expect(resources.sceneCoordinator.navigationRouteRoot.children.count == 2)
    #expect(resources.sceneCoordinator.navigationMarkerRoot.parent
            == resources.sceneCoordinator.navigationRouteRoot)
    #expect(resources.sceneCoordinator.navigationMarkerRoot.children.count == 1)
    for planet in resources.planets {
        let entities = try #require(resources.sceneCoordinator.bodyEntities[planet.name])
        let descriptor = manifest.assets.first { $0.displayName == planet.name }

        if let descriptor {
            let expectedScale = descriptor.modelToUniverseScale
                * (descriptor.renderRadius / descriptor.referenceRadius)
            #expect(entities.visualRoot.children.count == 1)
            #expect(entities.visualRoot.children.first?.name == descriptor.canonicalRootName)
            #expect(entities.visualRoot.scale == SIMD3<Float>(repeating: expectedScale))
            #expect(entities.visualRoot.position == SIMD3<Float>(
                descriptor.pivotCorrection.xAxis,
                descriptor.pivotCorrection.yAxis,
                descriptor.pivotCorrection.zAxis
            ))
        } else {
            #expect(entities.visualRoot.children.isEmpty)
        }
    }

    let sunVisualRoot = try #require(resources.sceneCoordinator.bodyEntities["Sun"]?.visualRoot)
    #expect(sunVisualRoot.findEntity(named: "Corona") != nil)
}

@MainActor
@Test func celestialBodyPreparationIsIdempotent() async throws {
    var loadCount = 0
    let repository = RealityAssetRepository { _ in
        loadCount += 1
        return makeCompleteAssetFixture()
    }
    let resources = UniverseModuleResources(assetRepository: repository)

    try await resources.prepare()
    try await resources.prepare()

    #expect(loadCount == 11)
    #expect(resources.sceneCoordinator.bodyEntities["Sun"]?.visualRoot.children.count == 1)
    #expect(resources.sceneCoordinator.bodyEntities["Neptune"]?.visualRoot.children.count == 1)
    #expect(descendantCount(
        named: CelestialLightingConfiguration.SunPointLight.entityName,
        in: resources.sceneCoordinator.universeRoot
    ) == 1)
}

@MainActor
@Test func failedCelestialBodyPreparationCommitsNoRealityKitOwnership() async throws {
    enum TestError: Error { case loadFailed }
    let repository = RealityAssetRepository { url in
        if url.lastPathComponent == "Neptune.usdz" {
            throw TestError.loadFailed
        }
        return makeCompleteAssetFixture()
    }
    let resources = UniverseModuleResources(assetRepository: repository)

    await #expect(throws: UniverseModulePreparationError.self) {
        try await resources.prepare()
    }

    #expect(resources.sceneCoordinator.realityKitOwnedBodyNames.isEmpty)
    #expect(resources.sceneCoordinator.bodyEntities["Sun"]?.visualRoot.children.isEmpty == true)
    #expect(resources.sceneCoordinator.bodyEntities["Neptune"]?.visualRoot.children.isEmpty == true)
}

@MainActor
@Test func celestialBodyPreparationCanRetryAfterFailure() async throws {
    enum TestError: Error { case loadFailed }
    var neptuneAttempts = 0
    let repository = RealityAssetRepository { url in
        if url.lastPathComponent == "Neptune.usdz" {
            neptuneAttempts += 1
            if neptuneAttempts == 1 {
                throw TestError.loadFailed
            }
        }
        return makeCompleteAssetFixture()
    }
    let resources = UniverseModuleResources(assetRepository: repository)

    await #expect(throws: UniverseModulePreparationError.self) {
        try await resources.prepare()
    }
    try await resources.prepare()

    #expect(neptuneAttempts == 2)
    #expect(resources.sceneCoordinator.realityKitOwnedBodyNames == Set(resources.planets.map(\.name)))
}

@MainActor
@Test func cancellingCelestialBodyPreparationCommitsNoBodies() async throws {
    var loadStarted = false
    let repository = RealityAssetRepository { _ in
        loadStarted = true
        try await Task.sleep(for: .seconds(10))
        let root = Entity()
        root.name = "Root"
        return root
    }
    let resources = UniverseModuleResources(assetRepository: repository)
    let manifest = try CelestialAssetManifestLoader.load()
    let preparation = Task { @MainActor in
        try await resources.sceneCoordinator.prepareCelestialBodies(from: manifest)
    }

    while !loadStarted {
        await Task.yield()
    }
    resources.sceneCoordinator.dismantle()

    await #expect(throws: CancellationError.self) {
        try await preparation.value
    }
    #expect(resources.sceneCoordinator.realityKitOwnedBodyNames.isEmpty)
    #expect(resources.sceneCoordinator.bodyEntities["Sun"]?.visualRoot.children.isEmpty == true)
    #expect(resources.sceneCoordinator.bodyEntities["Neptune"]?.visualRoot.children.isEmpty == true)
}

@MainActor
@Test func migratedBodiesUseManifestPresentationRadii() async throws {
    let resources = UniverseModuleResources()
    let manifest = try CelestialAssetManifestLoader.load()
    try await resources.prepare()

    resources.sceneSnapshotPipeline.requestPreparation(simulationTime: 0)
    while resources.sceneSnapshotPipeline.latestSnapshot == nil {
        await Task.yield()
    }
    let snapshot = try #require(resources.sceneSnapshotPipeline.latestSnapshot)

    for descriptor in manifest.assets {
        let packet = try #require(snapshot.planet(named: descriptor.displayName))
        #expect(packet.framingRadius == descriptor.framingRadius)
        #expect(packet.surfaceRadius == descriptor.surfaceRadius)
    }
}

@MainActor
@Test func everyMigratedBodyHasFiniteVisibleRealityKitGeometry() async throws {
    let resources = UniverseModuleResources()
    let manifest = try CelestialAssetManifestLoader.load()
    try await resources.prepare()
    resources.sceneSnapshotPipeline.requestPreparation(simulationTime: 0.1)
    while resources.sceneSnapshotPipeline.latestSnapshot == nil {
        await Task.yield()
    }
    resources.sceneCoordinator.setViewportSize(CGSize(width: 390, height: 844))
    resources.sceneCoordinator.update(deltaTime: 0.1)

    for descriptor in manifest.assets {
        let visualRoot = try #require(
            resources.sceneCoordinator.bodyEntities[descriptor.displayName]?.visualRoot
        )
        let rotationRoot = try #require(
            resources.sceneCoordinator.bodyEntities[descriptor.displayName]?.rotationTransform
        )
        let bounds = visualRoot.visualBounds(relativeTo: rotationRoot)
        #expect(!bounds.isEmpty)
        #expect(bounds.boundingRadius.isFinite)
        #expect(bounds.boundingRadius > 0)
        #expect(containsModelComponent(visualRoot))
        if descriptor.usesSnapshotScale {
            let tolerance = max(descriptor.renderRadius * 0.2, 0.000_01)
            #expect(abs(bounds.boundingRadius - descriptor.renderRadius) <= tolerance)
        }
    }
}

@MainActor
@Test func sceneSnapshotPipelineEmitsVisualSelfRotation() async throws {
    let planet = Planet(name: "Sun",
                        meshName: "Sun",
                        parentName: nil,
                        radius: 1,
                        distance: 2,
                        orbitSpeed: 0.25,
                        rotationSpeedKmSec: 0.5)
    let pipeline = UniverseSceneSnapshotPipeline(planets: [planet])
    pipeline.setPresentationMetrics([
        planet.name: CelestialBodyPresentationMetrics(renderRadius: 1,
                                                      framingRadius: 1,
                                                      surfaceRadius: 1)
    ])

    pipeline.requestPreparation(simulationTime: 2)
    while pipeline.latestSnapshot == nil {
        await Task.yield()
    }

    let packet = try #require(pipeline.latestSnapshot?.planet(named: planet.name))
    let expectedVisualRotation = float4x4.makeRotationY(1)
    let expectedOrbitTransform = planet.orbitTransformMatrix(at: 2)
    let expectedBaseModelMatrix = planet.modelMatrix(at: 2)
    expectSceneMatrix(packet.orbitTransformMatrix,
                      equals: expectedOrbitTransform)
    expectSceneMatrix(packet.visualRotationMatrix,
                      equals: expectedVisualRotation)
    expectSceneMatrix(packet.baseModelMatrix,
                      equals: expectedBaseModelMatrix)
    #expect(abs(packet.visualRotationMatrix[0][0] - 1) > 0.00001)
}

@MainActor
@Test func sceneSnapshotPipelineSpinsVisibleBodiesAroundRealityKitUpAxis() async throws {
    let bodyNames = Set(["Mercury", "Earth", "Jupiter", "Saturn", "Neptune"])
    let planets = SolarSystemLoader.loadPlanets(from: "planets")
        .filter { bodyNames.contains($0.name) }
    let pipeline = UniverseSceneSnapshotPipeline(planets: planets)
    pipeline.setPresentationMetrics(
        Dictionary(uniqueKeysWithValues: planets.map {
            ($0.name, CelestialBodyPresentationMetrics(renderRadius: 1,
                                                       framingRadius: 1,
                                                       surfaceRadius: 1))
        })
    )
    let simulationTime: Float = 100_000

    pipeline.requestPreparation(simulationTime: simulationTime)
    while pipeline.latestSnapshot == nil {
        await Task.yield()
    }

    let snapshot = try #require(pipeline.latestSnapshot)
    for planet in planets {
        let packet = try #require(snapshot.planet(named: planet.name))
        let expectedRotation = float4x4.makeRotationY(simulationTime * planet.rotationSpeedKmSec)
        expectSceneMatrix(packet.visualRotationMatrix,
                          equals: expectedRotation)
        #expect(abs(packet.visualRotationMatrix[1][1] - 1) <= 0.00001)
        #expect(abs(packet.visualRotationMatrix[0][1]) <= 0.00001)
        #expect(abs(packet.visualRotationMatrix[1][0]) <= 0.00001)
        #expect(abs(packet.visualRotationMatrix[1][2]) <= 0.00001)
        #expect(abs(packet.visualRotationMatrix[2][1]) <= 0.00001)
    }
}

@MainActor
@Test func sceneSnapshotPipelineEmitsParentRelativeOrbitMotion() async throws {
    let earth = Planet(name: "Earth",
                       meshName: "Earth",
                       parentName: nil,
                       radius: 1,
                       distance: 10,
                       orbitSpeed: 0,
                       rotationSpeedKmSec: 0)
    let moon = Planet(name: "Moon",
                      meshName: "Moon",
                      parentName: "Earth",
                      radius: 1,
                      distance: 2,
                      orbitSpeed: 0.5,
                      rotationSpeedKmSec: 0)
    let pipeline = UniverseSceneSnapshotPipeline(planets: [earth, moon])
    pipeline.setPresentationMetrics([
        earth.name: CelestialBodyPresentationMetrics(renderRadius: 1,
                                                     framingRadius: 1,
                                                     surfaceRadius: 1),
        moon.name: CelestialBodyPresentationMetrics(renderRadius: 1,
                                                    framingRadius: 1,
                                                    surfaceRadius: 1)
    ])

    pipeline.requestPreparation(simulationTime: Float.pi)
    while pipeline.latestSnapshot == nil {
        await Task.yield()
    }

    let snapshot = try #require(pipeline.latestSnapshot)
    let earthPacket = try #require(snapshot.planet(named: earth.name))
    let moonPacket = try #require(snapshot.planet(named: moon.name))
    let expectedMoonOrbit = moon.orbitTransformMatrix(
        at: Float.pi,
        parentWorldPosition: earthPacket.worldPosition
    )

    expectSceneMatrix(moonPacket.orbitTransformMatrix,
                      equals: expectedMoonOrbit)
    expectVector(earthPacket.worldPosition,
                 equals: SIMD3<Float>(10, 0, 0))
    expectVector(moonPacket.worldPosition,
                 equals: SIMD3<Float>(10, 0, -2))
}

@MainActor
@Test func migratedBodyAppliesVisualRotationAndRetainsVisualCorrection() async throws {
    let resources = UniverseModuleResources()
    try await resources.prepare()
    resources.sceneCoordinator.setViewportSize(CGSize(width: 390, height: 844))
    resources.sceneCoordinator.update(deltaTime: 0.1)
    let initialFrame = try #require(resources.sceneCoordinator.latestFrameState)
    let orbitTransform = float4x4.makeRotationY(.pi / 6)
        * float4x4.makeTranslation(SIMD3<Float>(2, 0, 0))
    let visualRotation = float4x4.makeRotationY(.pi / 3)
    let packet = CelestialBodySnapshot(
        planetName: "Sun",
        baseModelMatrix: orbitTransform * visualRotation,
        orbitTransformMatrix: orbitTransform,
        visualRotationMatrix: visualRotation,
        normalizedScale: 1,
        framingRadius: 1,
        surfaceRadius: 1,
        worldPosition: .zero
    )
    let snapshot = UniverseSceneSnapshot(frameID: 1,
                                          simulationTime: 0,
                                          planets: [packet])
    let frame = UniverseFrameState(simulationTime: 0,
                                   cameraSnapshot: initialFrame.cameraSnapshot,
                                   snapshot: snapshot,
                                   routes: initialFrame.routes)
    let sun = try #require(resources.sceneCoordinator.bodyEntities["Sun"])
    let visualTransform = sun.visualRoot.transform

    resources.sceneCoordinator.apply(frameState: frame)

    expectSceneMatrix(sun.orbitTransform.transform.matrix,
                      equals: orbitTransform)
    expectSceneMatrix(sun.rotationTransform.transform.matrix,
                      equals: visualRotation)
    #expect(sun.visualRoot.transform == visualTransform)
}

@MainActor
@Test func sceneCoordinatorAdvancesOneSharedFrameAtATime() throws {
    let resources = UniverseModuleResources()
    let coordinator = resources.sceneCoordinator
    coordinator.setViewportSize(CGSize(width: 390, height: 844))

    coordinator.update(deltaTime: 0.25)
    let firstFrame = try #require(coordinator.latestFrameState)
    coordinator.update(deltaTime: 0.5)
    let secondFrame = try #require(coordinator.latestFrameState)

    #expect(coordinator.updateCount == 2)
    #expect(firstFrame.simulationTime == 0.25)
    #expect(secondFrame.simulationTime == 0.75)
    #expect(firstFrame.cameraSnapshot.viewportSize == CGSize(width: 390, height: 844))
    #expect(secondFrame.cameraSnapshot.cameraRevision >= firstFrame.cameraSnapshot.cameraRevision)
}

@MainActor
// swiftlint:disable:next function_body_length
@Test func sceneCoordinatorAppliesSharedOriginAndProjectiveCamera() throws {
    let resources = UniverseModuleResources()
    let coordinator = resources.sceneCoordinator
    coordinator.setViewportSize(CGSize(width: 200, height: 100))
    resources.setObjectInfoOverlayFraming(isPresented: true,
                                          bottomInset: 40,
                                          viewportHeight: 100)
    coordinator.update(deltaTime: 0.5)
    let initialFrame = try #require(coordinator.latestFrameState)
    let bodyPosition = SIMD3<Float>(10, 20, 30)
    let orbitTransformMatrix = float4x4.makeTranslation(bodyPosition)
    let packet = CelestialBodySnapshot(
        planetName: "Earth",
        baseModelMatrix: orbitTransformMatrix,
        orbitTransformMatrix: orbitTransformMatrix,
        normalizedScale: 1,
        framingRadius: 1,
        surfaceRadius: 1,
        worldPosition: bodyPosition
    )
    let snapshot = UniverseSceneSnapshot(frameID: 1,
                                          simulationTime: 0,
                                          planets: [packet])
    let frame = UniverseFrameState(simulationTime: 0,
                                   cameraSnapshot: initialFrame.cameraSnapshot,
                                   snapshot: snapshot,
                                   routes: initialFrame.routes)

    coordinator.apply(frameState: frame)

    let earth = try #require(coordinator.bodyEntities["Earth"])
    #expect(earth.bodyRoot.position == -initialFrame.cameraSnapshot.sceneOrigin)
    expectSceneMatrix(earth.orbitTransform.transform.matrix,
                      equals: orbitTransformMatrix)
    let cameraComponent = try #require(
        coordinator.virtualCamera.components[ProjectiveTransformCameraComponent.self]
    )
    let realityKitCameraBasis = float4x4.makeRotationY(.pi)
    let expectedProjection = UniverseSceneCoordinator.makeRealityKitProjection(
        from: initialFrame.cameraSnapshot
    )
    let expectedCameraTransform = simd_inverse(initialFrame.cameraSnapshot.renderViewMatrix)
        * realityKitCameraBasis
    #expect(initialFrame.cameraSnapshot.projectionMatrix[2][1] < 0)
    expectSceneMatrix(cameraComponent.transform,
                      equals: expectedProjection)
    expectSceneMatrix(coordinator.virtualCamera.transformMatrix(relativeTo: coordinator.universeRoot),
                      equals: expectedCameraTransform)

    let worldPoint = SIMD4<Float>(bodyPosition, 1)
    let legacyClip = initialFrame.cameraSnapshot.projectionMatrix
        * initialFrame.cameraSnapshot.renderViewMatrix
        * worldPoint
    let realityKitClip = cameraComponent.transform
        * simd_inverse(expectedCameraTransform)
        * worldPoint
    #expect(abs(legacyClip.x + realityKitClip.x) < 0.00001)
    #expect(abs(legacyClip.y - realityKitClip.y) < 0.00001)
    #expect(abs(legacyClip.w - realityKitClip.w) < 0.00001)

    let centeredClip = cameraComponent.transform * SIMD4<Float>(0, 0, -1, 1)
    #expect(centeredClip.y / centeredClip.w < 0)

    let near = initialFrame.cameraSnapshot.dependencies.projection.nearPlane
    let far = initialFrame.cameraSnapshot.dependencies.projection.farPlane
    let nearClip = cameraComponent.transform * SIMD4<Float>(0, 0, -near, 1)
    let farClip = cameraComponent.transform * SIMD4<Float>(0, 0, -far, 1)
    #expect(abs((nearClip.z / nearClip.w) - 1) < 0.00001)
    #expect(abs(farClip.z / farClip.w) < 0.00001)
}

@MainActor
@Test func sceneCoordinatorKeepsLastCompleteSceneSnapshot() throws {
    let resources = UniverseModuleResources()
    let coordinator = resources.sceneCoordinator
    coordinator.setViewportSize(CGSize(width: 200, height: 100))

    coordinator.update(deltaTime: 0.1)
    let firstFrame = try #require(coordinator.latestFrameState)
    coordinator.update(deltaTime: 0.1)
    let secondFrame = try #require(coordinator.latestFrameState)

    #expect(secondFrame.snapshot?.frameID == firstFrame.snapshot?.frameID)
    coordinator.dismantle()
    #expect(coordinator.latestFrameState == nil)
}

@MainActor
@Test func inactiveSceneCoordinatorDoesNotAdvanceHiddenPresentation() throws {
    let resources = UniverseModuleResources()
    let coordinator = resources.sceneCoordinator
    coordinator.setViewportSize(CGSize(width: 200, height: 100))
    coordinator.update(deltaTime: 0.1)
    let visibleUpdateCount = coordinator.updateCount
    let visibleFrame = try #require(coordinator.latestFrameState)

    coordinator.setPresentationActive(false)
    coordinator.update(deltaTime: 1)

    #expect(coordinator.updateCount == visibleUpdateCount)
    #expect(coordinator.latestFrameState?.simulationTime == visibleFrame.simulationTime)

    coordinator.setPresentationActive(true)
    coordinator.update(deltaTime: 0.1)
    #expect(coordinator.updateCount == visibleUpdateCount + 1)
}

@MainActor
@Test func staleRealityViewTeardownDoesNotDismantleCurrentInstallation() {
    let resources = UniverseModuleResources()
    let coordinator = resources.sceneCoordinator
    let outgoingInstallation = UUID()
    let currentInstallation = UUID()

    coordinator.registerInstallation(outgoingInstallation)
    coordinator.registerInstallation(currentInstallation)
    coordinator.dismantle(installationID: outgoingInstallation)

    #expect(coordinator.activeInstallationID == currentInstallation)

    coordinator.dismantle(installationID: currentInstallation)
    #expect(coordinator.activeInstallationID == nil)
}

private func expectSceneMatrix(_ lhs: float4x4,
                               equals rhs: float4x4,
                               tolerance: Float = 0.00001) {
    for column in 0..<4 {
        for row in 0..<4 {
            #expect(abs(lhs[column][row] - rhs[column][row]) <= tolerance)
        }
    }
}

private func expectVector(_ lhs: SIMD3<Float>,
                          equals rhs: SIMD3<Float>,
                          tolerance: Float = 0.00001) {
    #expect(abs(lhs.x - rhs.x) <= tolerance)
    #expect(abs(lhs.y - rhs.y) <= tolerance)
    #expect(abs(lhs.z - rhs.z) <= tolerance)
}
