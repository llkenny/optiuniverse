import BaseModule
import Foundation
import simd
import Testing
@testable import UniverseModule

@MainActor
@Test func universeModuleResourcesNavigationFacadeIsObservableResource() throws {
    let resources = UniverseModuleResources()
    let navigation = resources.navigation

    #expect(ObjectIdentifier(navigation) == ObjectIdentifier(resources))
}

@MainActor
@Test func universeModuleResourcesTransferOrbitFacadeDelegatesWithoutRenderer() throws {
    let resources = UniverseModuleResources()
    let transferOrbit = resources.transferOrbit

    #expect(ObjectIdentifier(transferOrbit) == ObjectIdentifier(resources))

    transferOrbit.showTransferOrbit(to: "Mars")
    transferOrbit.clearTransferOrbit()

    #expect(!resources.transferOrbitController.isTransferPreviewActive)
}

@MainActor
@Test func universeModuleResourcesWiresFollowHandoffsWithoutRenderer() throws {
    let resources = UniverseModuleResources()

    #expect(resources.transferOrbitController.followPlanet != nil)
}

@MainActor
@Test func universeModuleResourcesManualCameraControlDisablesNavigationAutoFraming() throws {
    let resources = UniverseModuleResources()

    resources.navigationController.applyNavigation(named: "Mars",
                                                   snapshot: .navigationResourcesTestSnapshot)
    #expect(resources.navigationController.routeRenderState.isCameraAutoFramingEnabled)

    resources.beginManualCameraControl()

    #expect(resources.navigationController.routeRenderState.route != nil)
    #expect(!resources.navigationController.routeRenderState.isCameraAutoFramingEnabled)
    #expect(resources.navigationSnapshot.state == .running)
}

#if os(visionOS)
@MainActor
@Test func transferPreviewTemporarilyOverridesAndThenPersistsImmersiveFocus() throws {
    let resources = UniverseModuleResources()
    let coordinator = resources.sceneCoordinator
    coordinator.setViewportSize(CGSize(width: 1280, height: 720))
    coordinator.update(deltaTime: 0.1)

    resources.focusImmersivePlanet(named: "Earth")
    #expect(resources.isImmersiveFocusActive)

    resources.transferOrbit.showTransferOrbit(to: "Mars")
    coordinator.update(deltaTime: 0.1)

    #expect(resources.transferOrbitController.isTransferPreviewActive)
    #expect(!resources.isImmersiveFocusActive)
    #expect(coordinator.immersiveTransferOverviewTransform != nil)

    resources.transferOrbit.clearTransferOrbit()
    coordinator.update(deltaTime: 0.1)

    #expect(!resources.transferOrbitController.isTransferPreviewActive)
    #expect(coordinator.immersiveTransferOverviewTransform != nil)

    resources.beginManualCameraControl()

    #expect(coordinator.immersiveTransferOverviewTransform == nil)
    #expect(resources.isImmersiveFocusActive)

    resources.transferOrbit.showTransferOrbit(to: "Mars")
    coordinator.update(deltaTime: 0.1)
    resources.focusImmersivePlanet(named: "Earth")

    #expect(coordinator.immersiveTransferOverviewTransform == nil)
    #expect(resources.isImmersiveFocusActive)
}
#endif

@MainActor
@Test func universeModuleResourcesResolvesSurfaceFollowTargetByDestinationID() throws {
    let resources = UniverseModuleResources()
    let destinations = try decodeDestinationObjects("""
    [
      {
        "id": "BA41330B-C7FC-46B2-BAA9-E8CE85102A64",
        "object": "Moon",
        "title": "Moon Base",
        "subtitle": "First lunar outpost",
        "description": "A south pole surface destination.",
        "imageName": "dst-Moon_Base",
        "tag": "Base",
        "isNavigable": true,
        "surfaceLocation": {
          "latitudeDegrees": -90,
          "longitudeDegrees": 0
        },
        "details": [
          { "title": "Habitats", "value": "540", "dimension": "m3" }
        ]
      }
    ]
    """)
    let destination = try #require(destinations.first)

    let followTarget = try #require(resources.followTarget(for: destination.id,
                                                           destinations: destinations))
    let surfaceLocation = try #require(followTarget.surfaceLocation)

    #expect(followTarget.bodyName == "Moon")
    #expect(surfaceLocation.latitudeDegrees == -90)
    #expect(surfaceLocation.longitudeDegrees == 0)
}

@MainActor
@Test func universeModuleResourcesResolvesNonSurfaceFollowTargetByDestinationID() throws {
    let resources = UniverseModuleResources()
    let destinations = try decodeDestinationObjects("""
    [
      {
        "id": "2530E63D-699E-4F38-9B77-EABDE51152A5",
        "object": "Mars",
        "title": "Mars",
        "subtitle": "Red Planet",
        "description": "Dusty world.",
        "imageName": "dst-Mars",
        "tag": "Hot",
        "isNavigable": true,
        "details": [
          { "title": "Age", "value": "4.5B", "dimension": "YEARS" }
        ]
      }
    ]
    """)
    let destination = try #require(destinations.first)

    let followTarget = try #require(resources.followTarget(for: destination.id,
                                                           destinations: destinations))

    #expect(followTarget.bodyName == "Mars")
    #expect(followTarget.surfaceLocation == nil)
    #expect(resources.followTarget(for: UUID(), destinations: destinations) == nil)
}

private func decodeDestinationObjects(_ json: String) throws -> [DestinationObject] {
    try JSONDecoder().decode([DestinationObject].self, from: Data(json.utf8))
}

private extension UniverseSceneSnapshot {
    static var navigationResourcesTestSnapshot: UniverseSceneSnapshot {
        UniverseSceneSnapshot(frameID: 1,
                              simulationTime: 0,
                              planets: [
                                testPacket(name: "Sun",
                                           worldPosition: SIMD3<Float>(0, 0, 0),
                                           framingRadius: 0.2),
                                testPacket(name: "Earth",
                                           worldPosition: SIMD3<Float>(1, 0, 0),
                                           framingRadius: 0.05),
                                testPacket(name: "Mars",
                                           worldPosition: SIMD3<Float>(1.52, 0, 0),
                                           framingRadius: 0.05)
                              ])
    }

    static func testPacket(name: String,
                           worldPosition: SIMD3<Float>,
                           framingRadius: Float) -> CelestialBodySnapshot {
        CelestialBodySnapshot(planetName: name,
                              baseModelMatrix: matrix_identity_float4x4,
                              normalizedScale: 1,
                              framingRadius: framingRadius,
                              surfaceRadius: framingRadius,
                              worldPosition: worldPosition)
    }
}
