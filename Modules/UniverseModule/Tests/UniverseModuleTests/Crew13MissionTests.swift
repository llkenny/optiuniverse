import CoreGraphics
import Foundation
import RealityKit
import simd
import Testing
@testable import UniverseModule

private func crew13TestEarth(position: SIMD3<Float> = .zero, radius: Float = 1,
                             rotation: simd_float4x4 = matrix_identity_float4x4) -> CelestialBodySnapshot {
    CelestialBodySnapshot(planetName: "Earth", baseModelMatrix: matrix_identity_float4x4,
                          visualRotationMatrix: rotation, normalizedScale: 1,
                          framingRadius: radius * 1.03, surfaceRadius: radius, worldPosition: position)
}

@Test func crew13PhasesMatchTheSixtySecondFlight() throws {
    let profile = try #require(Crew13RouteProfile(earth: crew13TestEarth()))
    let times = [0.0, 8, 10, 16, 18, 36, 48, 58, 60]
    let phases: [MissionNavigationStatus.Phase] = [
        .launch, .separation, .secondStageBurn, .dragonSeparation, .orbit,
        .rendezvous, .docking, .docked, .docked
    ]
    for (time, phase) in zip(times, phases) {
        let flight = profile.sample(time: time)
        #expect(flight.status.mission == .crew13)
        #expect(flight.status.phase == phase)
        #expect(flight.status.totalOrbits == 0)
        #expect(flight.status.deployedSatelliteCount == 0)
    }
    #expect(profile.sample(time: 7.9).firstStageThrust == 1)
    #expect(profile.sample(time: 8).firstStageThrust == 0)
    #expect(profile.sample(time: 8).secondStageThrust == 1)
    #expect(profile.sample(time: 16).secondStageThrust == 0)
    #expect(profile.sample(time: 36).noseConeOpen == 1)
    #expect(profile.sample(time: 60).firstStageVisible == false)
    #expect(profile.sample(time: 60).secondStageVisible == false)
}

@Test func crew13PosesStayContinuousAtSeparationsAndPhaseBoundaries() throws {
    let profile = try #require(Crew13RouteProfile(earth: crew13TestEarth()))
    for time in [8.0, 10, 14, 16, 18, 22, 30, 36, 48, 58, 60] {
        let before = profile.sample(time: time - 0.0001)
        let after = profile.sample(time: time + 0.0001)
        for (start, end) in zip([before.dragon, before.firstStage, before.secondStage, before.station],
                               [after.dragon, after.firstStage, after.secondStage, after.station]) {
            #expect(distance(start.position, end.position) < 0.001)
            #expect(abs(dot(start.orientation.vector, end.orientation.vector)) > 0.9999)
        }
    }
    for time in stride(from: 0.0, through: 60, by: 0.125) {
        let flight = profile.sample(time: time)
        #expect(profile.sample(time: time) == flight)
        for pose in [flight.dragon, flight.firstStage, flight.secondStage, flight.station] {
            #expect(pose.position.x.isFinite && pose.position.y.isFinite && pose.position.z.isFinite)
            #expect(abs(length(pose.orientation.vector) - 1) < 0.0001)
        }
        #expect(length(flight.dragon.position) > 1.3)
        if time <= 36 { #expect(distance(flight.dragon.position, flight.station.position) > 0.7) }
    }
    #expect(profile.sample(time: -.infinity) == profile.sample(time: 0))
    #expect(profile.sample(time: .nan) == profile.sample(time: 0))
    #expect(profile.sample(time: 100) == profile.sample(time: 60))
}

@Test func crew13DockingPortsCoincideAndStayAttachedWhileOrbiting() throws {
    let profile = try #require(Crew13RouteProfile(earth: crew13TestEarth()))
    for time in stride(from: 58.0, through: 60, by: 0.125) {
        let flight = profile.sample(time: time)
        let dragonPort = flight.dragon.position + flight.dragon.orientation.act(
            Crew13RouteProfile.dragonDockingOffset * profile.vehicleScale)
        let stationPort = flight.station.position + flight.station.orientation.act(
            Crew13RouteProfile.stationDockingOffset * profile.stationScale)
        #expect(distance(dragonPort, stationPort) < 0.00001)
        #expect(dot(flight.dragon.orientation.act(SIMD3(0, 1, 0)),
                    flight.station.orientation.act(SIMD3(0, 1, 0))) < -0.9999)
    }
    #expect(distance(profile.sample(time: 58).station.position, profile.sample(time: 60).station.position) > 0.1)
}

@MainActor
@Test func crew13GeometryTracksEarthTranslationAndPreservesItsLaunchFrame() throws {
    let profile = try #require(Crew13RouteProfile(earth: crew13TestEarth()))
    let offset = SIMD3<Float>(10, -2, 3)
    let moved = profile.translated(to: offset)
    for time in [0.0, 8, 16, 36, 58, 60] {
        let original = profile.sample(time: time)
        let translated = moved.sample(time: time)
        for (start, end) in zip([original.dragon, original.firstStage, original.secondStage, original.station],
                               [translated.dragon, translated.firstStage, translated.secondStage, translated.station]) {
            #expect(distance(start.position, end.position - offset) < 0.00001)
            #expect(abs(dot(start.orientation.vector, end.orientation.vector)) > 0.9999)
        }
    }
    #expect(moved.normal == profile.normal)
    let rotated = try #require(Crew13RouteProfile(earth: crew13TestEarth(
        rotation: simd_float4x4(simd_quatf(angle: .pi / 2, axis: SIMD3(0, 1, 0))))))
    #expect(distance(rotated.launchDirection, profile.launchDirection) > 0.1)
    let route = profile.makeRoute()
    #expect(route.destinationName == "ISS")
    #expect(route.transfer == nil)
    #expect(route.withMission(.crew13).crew13Profile == profile)
    #expect(route.replacingPath(points: route.points, cumulativeDistances: route.cumulativeDistances,
                                totalDistance: route.totalDistance).crew13Profile == profile)
    for time in [0.0, 8, 18, 36, 48, 58, 60] {
        let progress = Float(time / 60)
        #expect(distance(try #require(route.point(at: progress)), profile.dragonPosition(time: time)) < 0.00001)
        let points = RealityProceduralSceneContent.navigationRenderPoints(route: route, progress: progress)
        #expect(distance(try #require(points.last), profile.dragonPosition(time: time)) < 0.00001)
    }
}

@Test func crew13RejectsInvalidEarthGeometry() {
    for radius: Float in [0, -1, .nan, .infinity] {
        #expect(Crew13RouteProfile(earth: crew13TestEarth(radius: radius)) == nil)
    }
    #expect(Crew13RouteProfile(earth: crew13TestEarth(position: SIMD3(.nan, 0, 0))) == nil)
    #expect(Crew13RouteProfile(earth: crew13TestEarth(rotation: simd_float4x4())) == nil)
}

@MainActor
@Test func crew13CoordinatorUsesActiveTimeAndRetainsIdentityAcrossSceneUpdates() throws {
    var published = NavigationRouteSnapshot.idle
    let coordinator = NavigationRouteCoordinator { published = $0 }
    let snapshot = UniverseSceneSnapshot(frameID: 0, simulationTime: 0, planets: [crew13TestEarth()])
    #expect(coordinator.start(destinationName: "ISS", planets: [], snapshot: snapshot, mission: .crew13))
    let routeID = try #require(coordinator.route?.id)
    coordinator.update(simulationTime: 1_000_000, delta: 36)
    #expect(published.elapsedTime == 36)
    #expect(published.remainingTime == 24)
    #expect(published.missionStatus?.phase == .rendezvous)
    coordinator.update(simulationTime: 9_000_000, delta: 0)
    #expect(published.elapsedTime == 36)
    let moved = crew13TestEarth(position: SIMD3(10, 0, 0),
                                rotation: simd_float4x4(simd_quatf(angle: .pi, axis: SIMD3(0, 1, 0))))
    let movedSnapshot = UniverseSceneSnapshot(frameID: 1, simulationTime: 9_000_000, planets: [moved])
    coordinator.refreshRoute(planets: [], snapshot: movedSnapshot)
    #expect(coordinator.route?.id == routeID)
    #expect(coordinator.route?.mission == .crew13)
    #expect(coordinator.route?.crew13Profile?.center == moved.worldPosition)
    #expect(coordinator.route?.crew13Profile?.normal
            == Crew13RouteProfile(earth: crew13TestEarth())?.normal)
    coordinator.update(delta: 24)
    #expect(published.state == .completed)
    #expect(published.destinationName == "ISS")
    #expect(published.missionStatus?.phase == .docked)
    #expect(published.progress == 1)
    #expect(published.remainingTime == 0)
    coordinator.cancel()
    #expect(published.mission == nil)
    #expect(coordinator.activeRouteForRendering == nil)
}

@MainActor
@Test func crew13CameraStaysOutsideEarthAndFramesBothDockingSubjects() throws {
    let profile = try #require(Crew13RouteProfile(earth: crew13TestEarth()))
    let route = profile.makeRoute()
    for viewport in [CGSize(width: 402, height: 874), CGSize(width: 874, height: 402)] {
        let camera = Crew13CameraMode()
        var pose = CameraPose(target: .zero, distance: 5, orientation: simd_quatf())
        for time in stride(from: 0.0, through: 60, by: 0.125) {
            let state = NavigationRouteRenderState(route: route, progress: Float(time / 60), elapsedTime: time)
            let frame = try #require(camera.frame(state: state, viewportSize: viewport, currentPose: pose))
            pose = CameraPose(target: frame.target, distance: frame.distance,
                              orientation: try #require(frame.orientation))
            #expect(pose.distance.isFinite)
            #expect(abs(length(pose.orientation.vector) - 1) < 0.0001)
            #expect(length(pose.position) > 1.05)
            if time >= 40 {
                let flight = profile.sample(time: time)
                // Check conservative bounds, not just the centers, against the fitted frustum.
                for (subject, radius) in [(flight.dragon.position, profile.vehicleScale * 0.6),
                                           (flight.station.position, profile.stationScale * 2.7)] {
                    let view = pose.orientation.inverse.act(subject - pose.position)
                    let horizontalLimit = -view.z * tan(CameraFit.verticalFieldOfView / 2)
                        * Float(viewport.width / viewport.height)
                    #expect(view.z < 0)
                    if time >= 48 { #expect(view.y - radius > 0) }
                    #expect(abs(view.x) + radius < horizontalLimit)
                    #expect(abs(view.y) + radius < -view.z * tan(CameraFit.verticalFieldOfView / 2))
                }
            }
        }
    }
}

@MainActor
@Test func crew13RendererReusesGeometryAndResetsAfterMissionReplacement() throws {
    let profile = try #require(Crew13RouteProfile(earth: crew13TestEarth()))
    let renderer = RealityCrew13Mission()
    let identities = renderer.root.children.map(ObjectIdentifier.init)
    let sceneOrigin = SIMD3<Float>(4, -1, 2)
    renderer.update(state: .init(route: profile.makeRoute(), progress: 1, elapsedTime: 60), sceneOrigin: sceneOrigin)
    #expect(renderer.root.isEnabled)
    #expect(!renderer.firstStage.isEnabled && !renderer.secondStage.isEnabled)
    let dragonPort = try #require(renderer.dragon.findEntity(named: "DragonDockingPort"))
    let stationPort = try #require(renderer.station.findEntity(named: "ISSDockingPort"))
    #expect(distance(dragonPort.position(relativeTo: renderer.root),
                     stationPort.position(relativeTo: renderer.root)) < 0.00001)
    let opened = renderer.noseCone.orientation
    renderer.update(state: .idle, sceneOrigin: .zero)
    #expect(!renderer.root.isEnabled)
    renderer.update(state: .init(route: profile.makeRoute(), progress: 0, elapsedTime: 0), sceneOrigin: .zero)
    #expect(renderer.firstStage.isEnabled && renderer.secondStage.isEnabled)
    #expect(abs(dot(renderer.noseCone.orientation.vector, opened.vector)) < 0.9)
    #expect(renderer.root.children.map(ObjectIdentifier.init) == identities)
    let starship = try #require(StarshipRouteProfile(earth: crew13TestEarth())).makeRoute()
    renderer.update(state: .init(route: starship, progress: 0, elapsedTime: 0), sceneOrigin: .zero)
    #expect(!renderer.root.isEnabled)
}

@MainActor
@Test func crew13SceneSupportsManualControlCompletionAndEarthRecovery() async throws {
    let resources = UniverseModuleResources()
    let viewport = CGSize(width: 402, height: 874)
    resources.setViewportSize(viewport)
    try await resources.prepare()
    resources.sceneCoordinator.update(deltaTime: 0)
    resources.navigation.startMission(.crew13)
    resources.sceneCoordinator.update(deltaTime: 2)
    let mode = NavigationCameraMode()
    for frame in 0..<116 {
        if frame % 6 == 0 {
            resources.rotateCamera(translation: CGSize(width: 80, height: -40))
            resources.scaleCamera(by: frame % 12 == 0 ? 3 : 0.4)
        }
        let orientation = resources.cameraCoordinator.currentCameraPose.orientation
        resources.sceneCoordinator.update(deltaTime: 0.5)
        let pose = resources.cameraCoordinator.currentCameraPose
        let state = resources.navigationController.routeRenderState
        let profile = try #require(state.route?.crew13Profile)
        #expect(!mode.isArrivalPhase(state: state))
        #expect(distance(pose.position, profile.center) >= profile.radius * 1.049)
        #expect(abs(dot(pose.orientation.vector, orientation.vector)) > 0.99999)
        #expect(mode.makeNavigationTransaction(state: state, snapshot: nil,
                                                viewportSize: viewport, currentPose: pose) == nil)
        let matrix = pose.makeRenderViewMatrix()
        for column in 0..<4 {
            for row in 0..<4 { #expect(matrix[column][row].isFinite) }
        }
    }
    #expect(resources.navigationSnapshot.state == .completed)
    #expect(resources.navigationSnapshot.missionStatus?.phase == .docked)
    resources.navigation.doneNavigation()
    #expect(resources.cameraCoordinator.followCameraOwner.followingPlanetName == "Earth")
    #expect(resources.cameraCoordinator.followCameraOwner.hasActiveTransition)
    resources.sceneCoordinator.update(deltaTime: 0.1)
    #expect(resources.sceneCoordinator.navigationMarkerRoot.findEntity(named: "Crew13")?.isEnabled == false)
    resources.navigation.startMission(.crew13)
    resources.sceneCoordinator.update(deltaTime: 0.1)
    #expect(resources.navigationSnapshot.missionStatus?.phase == .launch)
    resources.navigation.cancelNavigation()
    #expect(resources.cameraCoordinator.followCameraOwner.followingPlanetName == "Earth")
    #expect(resources.cameraCoordinator.followCameraOwner.hasActiveTransition)
}
