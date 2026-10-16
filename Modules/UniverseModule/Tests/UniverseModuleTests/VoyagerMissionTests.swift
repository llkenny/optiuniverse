import CoreGraphics
import Foundation
import RealityKit
import simd
import Testing
@testable import UniverseModule

@MainActor
private func voyagerResources(provider: (any CelestialStateProviding)? = nil) throws -> UniverseModuleResources {
    let resources = UniverseModuleResources(stateProvider: try provider ?? EphemerisArchive.bundled.get())
    resources.setViewportSize(CGSize(width: 402, height: 874))
    resources.sceneSnapshotPipeline.setPresentationMetrics(Dictionary(uniqueKeysWithValues: testPlanets.map {
        ($0.name, CelestialBodyPresentationMetrics(renderRadius: $0.radius,
            framingRadius: $0.radius * ($0.name == "Saturn" ? 2.4 : 1), surfaceRadius: $0.radius))
    }))
    resources.sceneCoordinator.update(deltaTime: 0)
    return resources
}

@Test func voyagerTimelineUsesHistoricalAnchorsAndHoldsLaunchAndEpilogue() throws {
    let timeline = MissionTimeline.forMission(.voyager1)
    let dates = [(0.0, "1977-09-05T12:56:01Z"), (15, "1977-09-05T12:56:01Z"),
                 (30, "1979-03-05T12:05:00Z"), (52, "1980-11-12T23:46:00Z"),
                 (82, "2012-08-25T00:00:00Z"), (90, "2012-08-25T00:00:00Z")]
    for (time, dateString) in dates {
        let date = try #require(ISO8601DateFormatter().date(from: dateString))
        #expect(abs(SimulationTime.date(forTDBSeconds: timeline.epoch(at: time)).timeIntervalSince(date)) < 0.001)
    }
    #expect(timeline.duration == 90)
    for (start, center, end) in [(24.0, 30.0, 36.0), (46.0, 52.0, 58.0)] {
        #expect(abs(timeline.epoch(at: center) - timeline.epoch(at: start) - 172_800) < 0.001)
        #expect(abs(timeline.epoch(at: end) - timeline.epoch(at: center) - 172_800) < 0.001)
    }
    let archive = try EphemerisArchive.bundled.get()
    try timeline.validateEphemeris(archive)
    #expect(archive.coverageYears == 1977...2100)
    let preview = TransferPreviewSnapshot(hasPartialOrbit: true, orbitCoverageYears: archive.coverageYears)
    #expect(preview.partialOrbitLabel == "Orbit arc · 1977–2100")
    let before = try #require(ISO8601DateFormatter().date(from: "1977-12-31T23:59:59Z"))
    let after = try #require(ISO8601DateFormatter().date(from: "1978-01-01T00:00:00Z"))
    #expect(abs(SimulationTime.tdbSeconds(for: after) - SimulationTime.tdbSeconds(for: before) - 2) < 0.0001)
}

@MainActor
@Test func voyagerFlybysClearDatedBodiesAndRouteRetainsContinuousMotion() throws {
    let resources = try voyagerResources()
    resources.navigation.startMission(.voyager1)
    let route = try #require(resources.navigationController.routeRenderState.route)
    let profile = try #require(route.voyagerProfile)
    let timeline = MissionTimeline.forMission(.voyager1)
    let archive = try EphemerisArchive.bundled.get()
    #expect(route.transfer == nil)
    #expect(route.hasMissionVehicles)
    #expect(route.missionEarthPreciseCenter == nil)
    #expect(route.withMission(.voyager1).voyagerProfile == profile)
    #expect(route.replacingPath(points: route.points, cumulativeDistances: route.cumulativeDistances,
                                totalDistance: route.totalDistance).voyagerProfile == profile)
    for time in stride(from: 0.0, through: 90, by: 0.125) {
        let flight = profile.sample(time: time)
        #expect(length(flight.probe.precisePosition).isFinite)
        #expect(abs(length(flight.probe.orientation.vector) - 1) < 0.0001)
        for planet in testPlanets {
            let body = try #require(CelestialBodyID(rawValue: planet.name))
            let center = try archive.state(for: body, at: timeline.epoch(at: time)).scenePosition
            let radius = Double(planet.radius) * (body == .saturn ? 2.4 : 1)
            #expect(distance(flight.probe.precisePosition, center) > radius)
        }
    }
    for boundary in [8.0, 12, 15, 24, 30, 36, 46, 52, 58, 77, 82] {
        let before = profile.precisePosition(time: boundary - 0.000_001)
        let after = profile.precisePosition(time: boundary + 0.000_001)
        #expect(distance(before, after) < 0.01)
        let leftVelocity = (profile.precisePosition(time: boundary) - before) / 0.000_001
        let rightVelocity = (after - profile.precisePosition(time: boundary)) / 0.000_001
        #expect(distance(leftVelocity, rightVelocity) < 0.1)
        let first = profile.sample(time: boundary - 0.000_001).probe.orientation
        let last = profile.sample(time: boundary + 0.000_001).probe.orientation
        #expect(abs(dot(first.vector, last.vector)) > 0.9999)
    }
    for (time, body) in [(30.0, CelestialBodyID.jupiter), (52.0, .saturn)] {
        let center = try archive.state(for: body, at: timeline.epoch(at: time)).scenePosition
        let flight = profile.sample(time: time)
        #expect(abs(distance(flight.probe.precisePosition, center) - Double(flight.focusRadius) * 3) < 1e-8)
    }
    #expect(profile.sample(time: .nan) == profile.sample(time: 0))
    #expect(profile.sample(time: 100) == profile.sample(time: 90))
    #expect(profile.precisePosition(time: 82) == profile.precisePosition(time: 90))
}

@MainActor
@Test func voyagerTrajectoryTurnsGraduallyAcrossCruiseAndFlybyJoins() throws {
    let resources = try voyagerResources()
    resources.navigation.startMission(.voyager1)
    let profile = try #require(resources.navigationController.routeRenderState.route?.voyagerProfile)
    func direction(_ time: Double) -> SIMD3<Double> {
        normalize(profile.precisePosition(time: time + 0.0001) - profile.precisePosition(time: time - 0.0001))
    }
    var largestTurn = 0.0
    // At 60 fps no approach/flyby frame should introduce a visible angular snap.
    for time in stride(from: 20.0, through: 64, by: 1.0 / 60) {
        let cosine = min(1, max(-1, dot(direction(time), direction(time + 1.0 / 60))))
        largestTurn = max(largestTurn, acos(cosine))
    }
    #expect(largestTurn < 5 * .pi / 180)
    for boundary in [24.0, 30, 36, 46, 52, 58] {
        let step = 0.0001
        func acceleration(_ time: Double) -> SIMD3<Double> {
            (profile.precisePosition(time: time + step) - 2 * profile.precisePosition(time: time)
                + profile.precisePosition(time: time - step)) / (step * step)
        }
        #expect(distance(acceleration(boundary - step), acceleration(boundary + step)) < 0.1)
    }
}

@MainActor
@Test func voyagerCameraAndGeometryUseTheSamePreciseFlightSample() throws {
    let resources = try voyagerResources()
    resources.navigation.startMission(.voyager1)
    let route = try #require(resources.navigationController.routeRenderState.route)
    let presenter = RealityVoyagerMission()
    let camera = VoyagerCameraMode()
    let viewport = CGSize(width: 402, height: 874)
    for time in [0.0, 8, 12, 15, 24, 30, 36, 46, 52, 58, 78, 82, 90] {
        let state = NavigationRouteRenderState(route: route, progress: Float(time / 90), elapsedTime: time)
        let flight = try #require(state.voyagerFlight)
        let frame = try #require(camera.frame(state: state, viewportSize: viewport,
                                              currentPose: resources.cameraState.pose))
        #expect(frame.distance.isFinite && frame.distance > CameraFit.minimumNearPlane)
        #expect(length(frame.preciseTarget).isFinite)
        #expect(state.preciseMarkerPosition == flight.probe.precisePosition)
        presenter.update(state: state, sceneOrigin: flight.probe.precisePosition)
        #expect(presenter.probe.position == .zero)
        #expect(presenter.probe.isEnabled == (time >= 12))
        #expect(presenter.rocket.isEnabled == (time < 13))
        #expect(presenter.centaur.isEnabled == (time < 16))
    }
    #expect(presenter.probe.findEntity(named: "HighGainAntenna") != nil)
    #expect(presenter.probe.findEntity(named: "GoldenRecord") != nil)
    presenter.update(state: .idle, sceneOrigin: .zero)
    #expect(!presenter.root.isEnabled)
}

@MainActor
@Test func voyagerReplayPausesHoldsCaptionAndReturnsToLiveSunOverview() throws {
    let resources = try voyagerResources()
    resources.navigation.startMission(.voyager1)
    let routeID = try #require(resources.navigationSnapshot.routeID)
    resources.sceneCoordinator.update(deltaTime: 30)
    #expect(resources.navigationSnapshot.missionStatus?.phase == .jupiterFlyby)
    let epoch = resources.sceneCoordinator.latestFrameState?.simulationTime
    resources.beginManualCameraControl()
    resources.sceneCoordinator.setPresentationActive(false)
    resources.sceneCoordinator.update(deltaTime: 3_600)
    resources.sceneCoordinator.setPresentationActive(true)
    resources.sceneCoordinator.update(deltaTime: 3_600)
    #expect(resources.navigationSnapshot.elapsedTime == 30)
    #expect(resources.sceneCoordinator.latestFrameState?.simulationTime == epoch)
    #expect(!resources.navigationController.routeRenderState.isCameraAutoFramingEnabled)
    resources.sceneCoordinator.update(deltaTime: 51.9)
    #expect(resources.navigationSnapshot.missionStatus?.epilogueText == nil)
    resources.sceneCoordinator.update(deltaTime: 0.1)
    let caption = resources.navigationSnapshot.missionStatus?.epilogueText
    #expect(caption == "Voyager 1 has left the heliosphere and continues its journey through interstellar space.")
    resources.sceneCoordinator.update(deltaTime: 8)
    #expect(resources.navigationSnapshot.state == .completed)
    #expect(resources.navigationSnapshot.remainingTime == 0)
    resources.sceneCoordinator.update(deltaTime: 10)
    #expect(resources.navigationSnapshot.missionStatus?.epilogueText == caption)
    resources.navigation.doneNavigation()
    #expect(resources.simulationSnapshot.mode == .live)
    #expect(resources.cameraCoordinator.followCameraOwner.followingPlanetName == "Sun")
    #expect(resources.navigationSnapshot.missionStatus?.epilogueText == nil)
    resources.sceneCoordinator.update(deltaTime: 2)
    #expect(resources.cameraState.cameraDistance > CameraState.defaultMaximumDistance)
    #expect(resources.cameraState.preciseCameraTarget == .zero)
    resources.navigation.startMission(.voyager1)
    #expect(resources.navigationSnapshot.routeID != routeID)
    #expect(resources.navigationSnapshot.elapsedTime == 0)
    resources.navigation.cancelNavigation()
    #expect(resources.simulationSnapshot.mode == .live)
    #expect(resources.cameraCoordinator.followCameraOwner.followingPlanetName == "Sun")
}

private struct VoyagerRestrictedProvider: CelestialStateProviding {
    let archive: EphemerisArchive
    let blockedEpoch: Double
    func state(for body: CelestialBodyID, at seconds: Double) throws -> CelestialBodyState {
        if abs(seconds - blockedEpoch) < 0.001 { throw CelestialStateError.outsideCoverage }
        return try archive.state(for: body, at: seconds)
    }
}

@MainActor
@Test func voyagerCompletionAutomaticallyReturnsToLiveLikeOtherMissions() async throws {
    let resources = try voyagerResources()
    resources.navigation.startMission(.voyager1)
    resources.sceneCoordinator.update(deltaTime: 90)
    #expect(resources.navigationSnapshot.state == .completed)
    #expect(resources.navigationSnapshot.missionStatus?.epilogueText != nil)
    // Other asset tests can occupy MainActor before the shared 1.1-second handoff
    // task starts. Wait for its observable result instead of assuming scheduler order.
    for _ in 0..<50 {
        if resources.simulationSnapshot.mode == .live { break }
        try await Task.sleep(for: .milliseconds(100))
    }
    #expect(resources.simulationSnapshot.mode == .live)
    #expect(resources.navigationSnapshot.missionStatus?.epilogueText == nil)
    #expect(resources.cameraCoordinator.followCameraOwner.followingPlanetName == "Sun")
}

@MainActor
@Test func voyagerMissingHistoryFailsAndRetryUsesRestoredData() throws {
    let archive = try EphemerisArchive.bundled.get()
    // A non-anchor sample exercises errors during route preparation, after timeline validation.
    let blocked = MissionTimeline.forMission(.voyager1).epoch(at: 20)
    let resources = try voyagerResources(provider: VoyagerRestrictedProvider(archive: archive, blockedEpoch: blocked))
    resources.navigation.startMission(.voyager1)
    #expect(resources.navigationSnapshot.state == .failed)
    #expect(resources.navigationSnapshot.mission == .voyager1)
    #expect(resources.navigationSnapshot.failure == .ephemerisUnavailable)
    #expect(resources.simulationSnapshot.mode == .live)
    resources.sceneSnapshotPipeline.setStateProvider(archive)
    resources.navigation.startMission(.voyager1)
    #expect(resources.navigationSnapshot.state == .running)
    #expect(resources.navigationSnapshot.mission == .voyager1)
    resources.navigation.startMission(.crew13)
    #expect(resources.navigationController.routeRenderState.voyagerFlight == nil)
    #expect(resources.navigationSnapshot.mission == .crew13)
}
