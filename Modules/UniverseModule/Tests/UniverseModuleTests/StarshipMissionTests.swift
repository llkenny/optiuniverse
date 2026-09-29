import CoreGraphics
import Foundation
import RealityKit
import simd
import Testing
@testable import UniverseModule

@MainActor
private final class StarshipCameraSnapshotSource: UniverseSceneSnapshotProviding {
    var latestSnapshot: UniverseSceneSnapshot?
    func requestPreparation(simulationTime: Double) {}
}

@MainActor
@Test func starshipManualCameraRemainsInControlThroughSplashdown() throws {
    let route = try #require(StarshipRouteProfile(earth: starshipTestEarth())).makeRoute()
    let camera = CameraState()
    let source = StarshipCameraSnapshotSource()
    let provider = SnapshotProvider(cameraState: camera, snapshotSource: source)
    let coordinator = CameraCoordinator(cameraState: camera, snapshotProvider: provider)
    let chosenPose = camera.pose
    let mode = NavigationCameraMode()
    for time in [53.0, 54, 55, 59, 60] {
        let state = NavigationRouteRenderState(route: route, progress: Float(time / 60),
                                              elapsedTime: time, isCameraAutoFramingEnabled: false)
        #expect(!mode.isArrivalPhase(state: state))
        coordinator.updateFrameCamera(snapshot: nil, delta: 1 / 60,
                                      viewportSize: CGSize(width: 402, height: 874),
                                      modeState: .init(transferPreviewActive: false, transfer: nil, navigation: state))
        #expect(camera.pose == chosenPose)
    }
}

@MainActor
@Test func starshipManualTrackingCannotCarryCameraInsideEarth() throws {
    let profile = try #require(StarshipRouteProfile(earth: starshipTestEarth()))
    let route = profile.makeRoute()
    let camera = CameraState()
    let source = StarshipCameraSnapshotSource()
    let provider = SnapshotProvider(cameraState: camera, snapshotSource: source)
    let coordinator = CameraCoordinator(cameraState: camera, snapshotProvider: provider)
    let viewport = CGSize(width: 402, height: 874)
    coordinator.handOffNavigationCameraControl(
        navigation: .init(route: route, progress: 16 / 60, elapsedTime: 16),
        snapshot: nil, viewportSize: viewport)
    let radial = normalize(profile.shipPosition(time: 16) - profile.center)
    camera.commit(.init(cameraTarget: profile.shipPosition(time: 16), cameraDistance: 0.48,
                        cameraOrientation: simd_quatf(from: SIMD3(0, 0, 1), to: radial)))
    let chosenOrientation = camera.cameraOrientation
    for time in stride(from: 16.0, through: 60, by: 0.125) {
        coordinator.updateFrameCamera(
            snapshot: nil, delta: 0.125, viewportSize: viewport,
            modeState: .init(transferPreviewActive: false, transfer: nil,
                             navigation: .init(route: route, progress: Float(time / 60), elapsedTime: time,
                                               isCameraAutoFramingEnabled: false)))
        #expect(distance(camera.pose.position, profile.center) >= profile.radius * 1.049)
        #expect(distance(camera.cameraOrientation.vector, chosenOrientation.vector) < 0.00001)
        #expect(distance(camera.cameraTarget, profile.shipPosition(time: time)) < 0.0001)
    }
}

private func starshipTestEarth(position: SIMD3<Float> = .zero,
                               rotation: simd_float4x4 = matrix_identity_float4x4) -> CelestialBodySnapshot {
    CelestialBodySnapshot(planetName: "Earth", baseModelMatrix: matrix_identity_float4x4,
                          visualRotationMatrix: rotation, normalizedScale: 1,
                          framingRadius: 1.03, surfaceRadius: 1, worldPosition: position)
}

@Test func starshipMakesExactlyTwoCompleteVisualOrbits() throws {
    let profile = try #require(StarshipRouteProfile(earth: starshipTestEarth()))
    #expect(abs(profile.orbitalAngle(time: 44) - profile.orbitalAngle(time: 16) - 4 * .pi) < 0.00001)
    for time in stride(from: 16.0, through: 44.0, by: 0.1) {
        #expect(abs(length(profile.shipPosition(time: time)) - 1.4) < 0.00001)
    }
    #expect(distance(profile.shipPosition(time: 16), profile.shipPosition(time: 30)) < 0.00001)
    #expect(distance(profile.shipPosition(time: 16), profile.shipPosition(time: 44)) < 0.00001)
}

@Test func starshipPhaseBoundariesKeepPosesContinuous() throws {
    let profile = try #require(StarshipRouteProfile(earth: starshipTestEarth()))
    for time in [8.0, 10, 16, 19, 28.4, 30, 44, 46, 53, 56, 59, 60] {
        let before = profile.sample(time: time - 0.0001)
        let after = profile.sample(time: time + 0.0001)
        #expect(distance(before.ship.position, after.ship.position) < 0.001)
        #expect(abs(dot(before.ship.orientation.vector, after.ship.orientation.vector)) > 0.999)
        #expect(distance(before.booster.position, after.booster.position) < 0.001)
        #expect(abs(dot(before.booster.orientation.vector, after.booster.orientation.vector)) > 0.999)
    }
    #expect(profile.sample(time: 0).status.phase == .launch)
    #expect(profile.sample(time: 8).status.phase == .separation)
    #expect(profile.sample(time: 14).status.phase == .boosterReturn)
    #expect(profile.sample(time: 16).status.currentOrbit == 1)
    #expect(profile.sample(time: 21).status.phase == .deployment)
    #expect(profile.sample(time: 30).status.currentOrbit == 2)
    #expect(profile.sample(time: 60).status.phase == .splashdown)
}

@Test func starshipDeploymentIsDeterministicAndPersistsThroughLanding() throws {
    let profile = try #require(StarshipRouteProfile(earth: starshipTestEarth()))
    var previousCount = 0
    for time in stride(from: 0.0, through: 60.0, by: 0.125) {
        let flight = profile.sample(time: time)
        #expect(flight.satellites.count >= previousCount)
        #expect(flight.satellites.count <= 26)
        #expect(flight.satellites.count == flight.status.deployedSatelliteCount)
        #expect(profile.sample(time: time) == flight)
        #expect(length(flight.ship.position) >= 1.049)
        for satellite in flight.satellites { #expect(length(satellite.position) >= 1.39) }
        previousCount = flight.satellites.count
    }
    #expect(profile.sample(time: 18.9).satellites.isEmpty)
    #expect(profile.sample(time: 28.4).satellites.count == 26)
    #expect(profile.sample(time: 60).satellites.count == 26)
    #expect(profile.sample(time: 0).satellites.isEmpty)
}

@Test func starshipRemainsEarthRelativeWithoutRotatingTheOrbit() throws {
    let profile = try #require(StarshipRouteProfile(earth: starshipTestEarth()))
    let starbase = SurfaceCoordinateMath.localUnitVector(
        for: SurfaceCoordinate(latitudeDegrees: 25.997, longitudeDegrees: -97.156))
    #expect(distance(normalize(profile.shipPosition(time: 0)), starbase) < 0.00001)
    let offset = SIMD3<Float>(100, 2, -30)
    let moved = profile.translated(to: offset)
    #expect(distance(moved.sample(time: 22).ship.position - offset, profile.sample(time: 22).ship.position) < 0.00001)
    #expect(moved.normal == profile.normal)
    let rotation = simd_float4x4(simd_quatf(angle: .pi / 2, axis: SIMD3(0, 1, 0)))
    let rotated = try #require(StarshipRouteProfile(earth: starshipTestEarth(rotation: rotation)))
    #expect(distance(rotated.launchDirection, profile.launchDirection) > 0.1)
}

@MainActor
@Test func starshipCameraRemainsFiniteAndOutsideEarth() throws {
    let profile = try #require(StarshipRouteProfile(earth: starshipTestEarth()))
    let route = profile.makeRoute()
    let camera = StarshipCameraMode()
    var pose = CameraPose(target: .zero, distance: 5, orientation: simd_quatf())
    for time in stride(from: 0.0, through: 60.0, by: 0.125) {
        let state = NavigationRouteRenderState(route: route, progress: Float(time / 60), elapsedTime: time)
        let frame = try #require(camera.frame(state: state, viewportSize: CGSize(width: 402, height: 874), currentPose: pose))
        pose = CameraPose(target: frame.target, distance: frame.distance, orientation: try #require(frame.orientation))
        #expect(pose.distance.isFinite)
        #expect(pose.orientation.vector.x.isFinite)
        #expect(abs(length(pose.orientation.vector) - 1) < 0.0001)
        #expect(length(pose.position) > 1.001)
    }
}

@MainActor
@Test func starshipRendererReusesEntitiesAndClearsOnCancelOrReplacement() throws {
    let profile = try #require(StarshipRouteProfile(earth: starshipTestEarth()))
    let route = profile.makeRoute()
    let renderer = RealityStarshipMission()
    let identities = renderer.satellites.map(ObjectIdentifier.init)
    renderer.update(state: NavigationRouteRenderState(route: route, progress: 0.5, elapsedTime: 30), sceneOrigin: .zero)
    #expect(renderer.root.isEnabled)
    #expect(renderer.satellites.filter(\.isEnabled).count == 26)
    #expect(!renderer.booster.isEnabled)
    renderer.update(state: .idle, sceneOrigin: .zero)
    #expect(!renderer.root.isEnabled)
    renderer.update(state: NavigationRouteRenderState(route: profile.makeRoute(), progress: 0, elapsedTime: 0), sceneOrigin: .zero)
    #expect(renderer.satellites.filter(\.isEnabled).isEmpty)
    #expect(renderer.booster.isEnabled)
    #expect(renderer.satellites.map(ObjectIdentifier.init) == identities)
    #expect(renderer.root.children.count == 30)
}

@MainActor
@Test func starshipCoordinatorPreservesIdentityAndUsesActivePlaybackTime() throws {
    let earth = starshipTestEarth()
    let snapshot = UniverseSceneSnapshot(frameID: 0, simulationTime: 0, planets: [earth])
    var published = NavigationRouteSnapshot.idle
    let coordinator = NavigationRouteCoordinator { published = $0 }
    #expect(coordinator.start(destinationName: "Earth", planets: [], snapshot: snapshot, mission: .starshipFlight14))
    let originalID = try #require(coordinator.route?.id)
    coordinator.update(simulationTime: 1_000_000, delta: 20)
    #expect(published.elapsedTime == 20)
    #expect(published.missionStatus?.phase == .deployment)
    coordinator.update(simulationTime: 9_000_000, delta: 0)
    #expect(published.elapsedTime == 20)
    coordinator.refreshRoute(planets: [], snapshot: UniverseSceneSnapshot(frameID: 1, simulationTime: 9_000_000,
                                                                         planets: [starshipTestEarth(position: SIMD3(10, 0, 0))]))
    #expect(coordinator.route?.id == originalID)
    #expect(coordinator.route?.mission == .starshipFlight14)
    coordinator.update(delta: 40)
    #expect(published.state == .completed)
    #expect(published.missionStatus?.phase == .splashdown)
    coordinator.cancel()
    #expect(published.mission == nil)
    #expect(coordinator.activeRouteForRendering == nil)
}

@MainActor
@Test func starshipSceneSupportsRepeatedManualZoomAndRotation() async throws {
    let resources = UniverseModuleResources()
    resources.setViewportSize(CGSize(width: 402, height: 874))
    try await resources.prepare()
    resources.sceneCoordinator.update(deltaTime: 0)
    resources.navigation.startMission(.starshipFlight14)
    resources.sceneCoordinator.update(deltaTime: 2)
    for frame in 0..<116 {
        if frame % 6 == 0 {
            resources.rotateCamera(translation: CGSize(width: 80, height: -40))
            resources.scaleCamera(by: frame % 12 == 0 ? 3 : 0.4)
        }
        let orientation = resources.cameraCoordinator.currentCameraPose.orientation
        resources.sceneCoordinator.update(deltaTime: 0.5)
        let pose = resources.cameraCoordinator.currentCameraPose
        let profile = try #require(resources.navigationController.routeRenderState.route?.starshipProfile)
        #expect(distance(pose.position, profile.center) >= profile.radius * 1.049)
        #expect(distance(pose.orientation.vector, orientation.vector) < 0.00001)
        let matrix = pose.makeRenderViewMatrix()
        for column in 0..<4 {
            for row in 0..<4 { #expect(matrix[column][row].isFinite) }
        }
    }
    #expect(resources.navigationSnapshot.state == .completed)
    resources.navigation.doneNavigation()
}

@MainActor
@Test func starshipSceneRunsEntireMissionAndHandsOffCleanly() async throws {
    let resources = UniverseModuleResources()
    resources.setViewportSize(CGSize(width: 402, height: 874))
    try await resources.prepare()
    resources.sceneCoordinator.update(deltaTime: 0)
    resources.navigation.startMission(.starshipFlight14)
    #expect(resources.navigationSnapshot.state == .running)
    for _ in 0..<120 {
        resources.sceneCoordinator.update(deltaTime: 0.5)
        let pose = resources.cameraCoordinator.currentCameraPose
        #expect(pose.distance.isFinite)
        #expect(pose.target.x.isFinite)
    }
    #expect(resources.navigationSnapshot.state == .completed)
    #expect(resources.navigationSnapshot.missionStatus?.deployedSatelliteCount == 26)
    resources.navigation.doneNavigation()
    #expect(resources.cameraCoordinator.followCameraOwner.hasActiveTransition)
    for _ in 0..<120 { resources.sceneCoordinator.update(deltaTime: 1.0 / 60.0) }
    #expect(resources.navigationSnapshot.state == .cancelled)
    #expect(resources.sceneCoordinator.navigationMarkerRoot.findEntity(named: "StarshipFlight14")?.isEnabled == false)
    resources.navigation.startMission(.starshipFlight14)
    resources.sceneCoordinator.update(deltaTime: 0.1)
    #expect(resources.navigationSnapshot.missionStatus?.phase == .launch)
    #expect(resources.navigationSnapshot.missionStatus?.deployedSatelliteCount == 0)
    resources.navigation.cancelNavigation()
    #expect(resources.cameraCoordinator.followCameraOwner.followingPlanetName == "Earth")
    #expect(resources.cameraCoordinator.followCameraOwner.hasActiveTransition)
}
