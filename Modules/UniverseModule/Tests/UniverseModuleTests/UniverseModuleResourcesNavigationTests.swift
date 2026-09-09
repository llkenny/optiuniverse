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
    #expect(resources.navigationController.navigationDidComplete != nil)
}

@MainActor
@Test func universeModuleResourcesNavigationCompletionFollowsDestination() throws {
    let resources = UniverseModuleResources()
    let initialPose = resources.cameraCoordinator.currentCameraPose

    resources.navigationController.navigationDidComplete?("Mars")

    #expect(resources.cameraCoordinator.followCameraOwner.followingPlanetName == "Mars")
    #expect(!resources.cameraCoordinator.followCameraOwner.hasActiveTransition)
    #expect(resources.cameraCoordinator.currentCameraPose == initialPose)
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

@MainActor
@Test func universeModuleResourcesPausedArtemisManualControlKeepsRoutePivot() async throws {
    let resources = UniverseModuleResources()
    let viewportSize = CGSize(width: 400, height: 400)
    resources.setViewportSize(viewportSize)
    _ = try await prepareCislunarSnapshot(for: resources)

    resources.navigation.startNavigation(from: "Earth", via: "Moon", to: "Earth")
    resources.navigation.pauseNavigation()
    resources.sceneCoordinator.update(deltaTime: 1.0 / 60.0)

    let pausedRenderState = resources.navigationController.routeRenderState
    let pausedRoute = try #require(pausedRenderState.route)
    let marker = try #require(pausedRoute.point(at: pausedRenderState.progress))
    let pausedNavigationPose = resources.cameraCoordinator.currentCameraPose
    let initialMarkerScreenPosition = projectedScreenPosition(point: marker,
                                                              pose: pausedNavigationPose,
                                                              viewportSize: viewportSize)
    let markerDistanceBeforeRotation = simd_distance(marker, pausedNavigationPose.position)

    resources.rotateCamera(translation: CGSize(width: 0, height: 14),
                           velocity: .zero)
    let rotatedPose = resources.cameraCoordinator.currentCameraPose

    #expect(resources.navigationSnapshot.state == .paused)
    #expect(resources.navigationController.routeRenderState.route?.id == pausedRoute.id)
    #expect(!resources.navigationController.routeRenderState.isCameraAutoFramingEnabled)
    expectVector(SIMD3<Float>(projectedScreenPosition(point: marker,
                                                      pose: rotatedPose,
                                                      viewportSize: viewportSize), 0),
                 equals: SIMD3<Float>(initialMarkerScreenPosition, 0))
    #expect(simd_distance(rotatedPose.position, pausedNavigationPose.position) > 0.0001)
    #expect(abs(simd_distance(marker, rotatedPose.position) - markerDistanceBeforeRotation) < 0.0001)

    for _ in 0..<3 {
        resources.sceneCoordinator.update(deltaTime: 1.0 / 60.0)
    }
    let refreshedRenderState = resources.navigationController.routeRenderState
    let refreshedRoute = try #require(refreshedRenderState.route)
    let refreshedMarker = try #require(refreshedRoute.point(at: refreshedRenderState.progress))
    let refreshedPose = resources.cameraCoordinator.currentCameraPose
    expectVector(SIMD3<Float>(projectedScreenPosition(point: refreshedMarker,
                                                      pose: refreshedPose,
                                                      viewportSize: viewportSize), 0),
                 equals: SIMD3<Float>(initialMarkerScreenPosition, 0))

    let markerDistanceBeforeZoom = simd_distance(refreshedMarker, refreshedPose.position)
    resources.scaleCamera(by: 1.2,
                          velocity: 0)
    let zoomedPose = resources.cameraCoordinator.currentCameraPose

    #expect(resources.navigationSnapshot.state == .paused)
    #expect(resources.navigationController.routeRenderState.route?.id == pausedRoute.id)
    #expect(!resources.navigationController.routeRenderState.isCameraAutoFramingEnabled)
    let zoomedRenderState = resources.navigationController.routeRenderState
    let zoomedRoute = try #require(zoomedRenderState.route)
    let zoomedMarker = try #require(zoomedRoute.point(at: zoomedRenderState.progress))
    expectVector(SIMD3<Float>(projectedScreenPosition(point: zoomedMarker,
                                                      pose: zoomedPose,
                                                      viewportSize: viewportSize), 0),
                 equals: SIMD3<Float>(initialMarkerScreenPosition, 0))
    #expect(simd_distance(zoomedMarker, zoomedPose.position) < markerDistanceBeforeZoom)
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

@MainActor
private func prepareCislunarSnapshot(for resources: UniverseModuleResources) async throws
-> UniverseSceneSnapshot {
    let metrics = CelestialBodyPresentationMetrics(renderRadius: 0.05,
                                                   framingRadius: 0.05,
                                                   surfaceRadius: 0.05)
    resources.sceneSnapshotPipeline.setPresentationMetrics([
        "Sun": CelestialBodyPresentationMetrics(renderRadius: 0.2,
                                                framingRadius: 0.2,
                                                surfaceRadius: 0.2),
        "Earth": metrics,
        "Moon": CelestialBodyPresentationMetrics(renderRadius: 0.02,
                                                 framingRadius: 0.02,
                                                 surfaceRadius: 0.02)
    ])
    resources.sceneSnapshotPipeline.requestPreparation(simulationTime: 0)

    for _ in 0..<50 {
        await Task.yield()
        if let snapshot = resources.snapshotProvider.latestSnapshot,
           snapshot.worldPosition(ofPlanetNamed: "Sun") != nil,
           snapshot.worldPosition(ofPlanetNamed: "Earth") != nil,
           snapshot.worldPosition(ofPlanetNamed: "Moon") != nil {
            return snapshot
        }
    }

    return try #require(resources.snapshotProvider.latestSnapshot)
}

private func expectVector(_ lhs: SIMD3<Float>,
                          equals rhs: SIMD3<Float>,
                          tolerance: Float = 0.0001) {
    #expect(simd_distance(lhs, rhs) < tolerance)
}

private func projectedScreenPosition(point: SIMD3<Float>,
                                     pose: CameraPose,
                                     viewportSize: CGSize,
                                     projection: CameraProjectionParameters = CameraProjectionParameters(
                                        nearPlane: 0.1,
                                        farPlane: 100
                                     )) -> SIMD2<Float> {
    let aspect = Float(viewportSize.width / viewportSize.height)
    let projectionMatrix = float4x4.perspective(fov: projection.verticalFieldOfView,
                                                aspect: aspect,
                                                near: projection.nearPlane,
                                                far: projection.farPlane,
                                                verticalCenterOffset: projection.verticalCenterOffset)
    let clipPosition = projectionMatrix * pose.makeRenderViewMatrix() * SIMD4<Float>(point - pose.target, 1)

    return SIMD2<Float>(clipPosition.x / clipPosition.w,
                        clipPosition.y / clipPosition.w)
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
