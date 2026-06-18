import CoreGraphics
import Metal
import RealityKit
import Testing
@testable import UniverseModule

@MainActor
@Test func sceneCoordinatorBuildsCanonicalHierarchy() throws {
    _ = try #require(MTLCreateSystemDefaultDevice())
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

    let earth = try #require(coordinator.bodyEntities["Earth"])
    #expect(earth.bodyRoot.parent == coordinator.celestialSystemRoot)
    #expect(earth.orbitTransform.parent == earth.bodyRoot)
    #expect(earth.rotationTransform.parent == earth.orbitTransform)
    #expect(earth.visualRoot.parent == earth.rotationTransform)
}

@MainActor
@Test func sceneCoordinatorAdvancesOneSharedFrameAtATime() throws {
    _ = try #require(MTLCreateSystemDefaultDevice())
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
@Test func sceneCoordinatorAppliesSharedOriginAndProjectiveCamera() throws {
    _ = try #require(MTLCreateSystemDefaultDevice())
    let resources = UniverseModuleResources()
    let coordinator = resources.sceneCoordinator
    coordinator.setViewportSize(CGSize(width: 200, height: 100))
    resources.setObjectInfoOverlayFraming(isPresented: true,
                                          bottomInset: 40,
                                          viewportHeight: 100)
    coordinator.update(deltaTime: 0.5)
    let initialFrame = try #require(coordinator.latestFrameState)
    let bodyPosition = SIMD3<Float>(10, 20, 30)
    let packet = PreparedPlanetRenderPacket(
        planetName: "Earth",
        meshes: [],
        baseModelMatrix: matrix_identity_float4x4,
        worldModelMatrix: matrix_identity_float4x4,
        normalizedScale: 1,
        primaryMeshRadius: 1,
        framingRadius: 1,
        surfaceRadius: 1,
        worldPosition: bodyPosition
    )
    let snapshot = PreparedRenderSnapshot(frameID: 1,
                                          simulationTime: 0,
                                          planets: [packet])
    let frame = UniverseFrameState(simulationTime: 0,
                                   cameraSnapshot: initialFrame.cameraSnapshot,
                                   snapshot: snapshot,
                                   routes: initialFrame.routes)

    coordinator.apply(frameState: frame)

    let earth = try #require(coordinator.bodyEntities["Earth"])
    #expect(earth.bodyRoot.position == bodyPosition - initialFrame.cameraSnapshot.sceneOrigin)
    let cameraComponent = try #require(
        coordinator.virtualCamera.components[ProjectiveTransformCameraComponent.self]
    )
    #expect(initialFrame.cameraSnapshot.projectionMatrix[2][1] < 0)
    expectSceneMatrix(cameraComponent.transform,
                      equals: initialFrame.cameraSnapshot.projectionMatrix)
    expectSceneMatrix(coordinator.virtualCamera.transformMatrix(relativeTo: coordinator.universeRoot),
                      equals: simd_inverse(initialFrame.cameraSnapshot.renderViewMatrix))
}

@MainActor
@Test func sceneCoordinatorKeepsLastCompletePreparedSnapshot() throws {
    _ = try #require(MTLCreateSystemDefaultDevice())
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

private func expectSceneMatrix(_ lhs: float4x4,
                               equals rhs: float4x4,
                               tolerance: Float = 0.00001) {
    for column in 0..<4 {
        for row in 0..<4 {
            #expect(abs(lhs[column][row] - rhs[column][row]) <= tolerance)
        }
    }
}
