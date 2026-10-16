import CoreGraphics
import Foundation
import simd
import Testing
@testable import UniverseModule

private func missionDate(_ value: String) -> Date {
    ISO8601DateFormatter().date(from: value)!
}

@MainActor
private func missionResources(stateProvider: (any CelestialStateProviding)? = nil,
                              now: @escaping () -> Date = Date.init) throws -> UniverseModuleResources {
    let resources = UniverseModuleResources(stateProvider: try stateProvider ?? EphemerisArchive.bundled.get(),
                                            now: now)
    resources.setViewportSize(CGSize(width: 402, height: 874))
    // Clock/navigation integration needs physical body metrics, not imported texture-heavy assets.
    resources.sceneSnapshotPipeline.setPresentationMetrics(Dictionary(uniqueKeysWithValues: resources.planets.map {
        ($0.name, CelestialBodyPresentationMetrics(renderRadius: $0.radius,
                                                   framingRadius: $0.radius, surfaceRadius: $0.radius))
    }))
    resources.sceneCoordinator.update(deltaTime: 0)
    return resources
}

private func expectMissionDate(_ epoch: Double, _ date: String, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(abs(SimulationTime.date(forTDBSeconds: epoch).timeIntervalSince(missionDate(date))) < 0.001,
            sourceLocation: sourceLocation)
}

@Test func missionTimelinesMatchPublishedUTCAnchorsAndInterpolate() {
    let artemis = MissionTimeline.forMission(.artemisII)
    expectMissionDate(artemis.epoch(at: 0), "2026-04-01T22:35:00Z")
    let encounter = artemis.anchors[1]
    expectMissionDate(artemis.epoch(at: encounter.playbackTime), "2026-04-06T23:00:00Z")
    #expect(abs(ArtemisRouteProfile.routeProgress(linearProgress: Float(encounter.playbackTime / 16),
                                                 estimatedDuration: 16) - 0.58) < 1e-6)
    expectMissionDate(artemis.epoch(at: 16), "2026-04-11T00:07:00Z")
    let starship = MissionTimeline.forMission(.starshipFlight14)
    for (time, date) in [(0.0, "2026-09-28T12:48:00Z"), (19, "2026-09-28T13:22:00Z"),
                         (28.4, "2026-09-28T13:52:00Z"), (46, "2026-09-28T15:28:00Z"),
                         (60, "2026-09-28T15:56:00Z")] {
        expectMissionDate(starship.epoch(at: time), date)
    }
    let crew = MissionTimeline.forMission(.crew13)
    expectMissionDate(crew.epoch(at: 0), "2026-10-01T15:10:00Z")
    expectMissionDate(crew.epoch(at: 58), "2026-10-01T23:05:00Z")
    #expect(crew.epoch(at: 59) == crew.arrivalEpoch)
    #expect(crew.epoch(at: 60) == crew.arrivalEpoch)
    for timeline in [artemis, starship, crew] {
        for (left, right) in zip(timeline.anchors, timeline.anchors.dropFirst()) {
            let middle = (left.playbackTime + right.playbackTime) / 2
            #expect(abs(timeline.epoch(at: middle) - (left.epoch + right.epoch) / 2) < 1e-6)
        }
    }
}

@Test(arguments: [MissionFlightPlan.artemisII, .starshipFlight14, .crew13])
func missionClockIsIndependentOfFramePartitionAndHoldsCompletion(mission: MissionFlightPlan) {
    let replay = MissionReplay(id: UUID(), mission: mission)
    let now = missionDate("2026-10-16T10:00:00Z")
    var fine = UniverseSimulationClock(now: { now })
    var coarse = UniverseSimulationClock(now: { now })
    fine.prepareMission(replay)
    for delta in [0, -1, Double.nan, .infinity] {
        _ = fine.advance(by: delta, mission: replay)
        #expect(fine.missionElapsedTime == 0)
        #expect(fine.currentTime == replay.timeline.departureEpoch)
        #expect(fine.presentationTime == 0)
    }
    for _ in 0..<600 { _ = fine.advance(by: replay.timeline.duration / 600, mission: replay) }
    _ = coarse.advance(by: replay.timeline.duration, mission: replay)
    #expect(fine.currentTime == coarse.currentTime)
    #expect(fine.missionElapsedTime == replay.timeline.duration)
    #expect(fine.mode == .missionReplay)
    let endpoint = fine.currentTime
    _ = fine.advance(by: 10, mission: replay)
    #expect(fine.currentTime == endpoint)
    #expect(fine.presentationTime > replay.timeline.duration)
    for delta in [0, -1, Double.nan, .infinity] {
        let previousPresentation = fine.presentationTime
        _ = fine.advance(by: delta, mission: replay)
        #expect(fine.currentTime == endpoint)
        #expect(fine.presentationTime == previousPresentation)
    }
    let restart = MissionReplay(id: UUID(), mission: mission)
    _ = fine.advance(by: 0, mission: restart)
    #expect(fine.missionElapsedTime == 0)
    #expect(fine.currentTime == replay.timeline.departureEpoch)
    _ = fine.advance(by: 0)
    #expect(fine.mode == .live)
    #expect(fine.currentTime == SimulationTime.tdbSeconds(for: now))
}

@Test func pendingMissionClockHoldsLiftoffWithoutStoppingPresentation() {
    let replay = MissionReplay(id: UUID(), mission: .artemisII, isPreparing: true)
    var clock = UniverseSimulationClock()
    _ = clock.advance(by: 5, mission: replay)
    #expect(clock.missionElapsedTime == 0)
    #expect(clock.currentTime == replay.timeline.departureEpoch)
    #expect(clock.presentationTime == 5)
}

@MainActor
@Test(arguments: [MissionFlightPlan.artemisII, .starshipFlight14, .crew13])
func missionSceneUsesDatedBodiesAndSharedTimeAcrossPauseRestartAndExit(mission: MissionFlightPlan) throws {
    var wallDate = missionDate("2026-10-16T10:00:00Z")
    let resources = try missionResources(now: { wallDate })
    resources.navigation.startMission(mission)
    let timeline = MissionTimeline.forMission(mission)
    let routeID = try #require(resources.navigationSnapshot.routeID)
    #expect(resources.simulationSnapshot.mode == .missionReplay)
    #expect(resources.simulationSnapshot.dateUTC == SimulationTime.date(forTDBSeconds: timeline.departureEpoch))
    let launchRoute = try requireDatedMissionLaunch(resources: resources, mission: mission)
    resources.sceneCoordinator.update(deltaTime: 4)
    let epoch = try #require(resources.sceneCoordinator.latestFrameState?.simulationTime)
    #expect(epoch == timeline.epoch(at: 4))
    #expect(resources.navigationSnapshot.elapsedTime == 4)
    let snapshot = try #require(resources.snapshotProvider.latestSnapshot)
    let earth = try #require(snapshot.planet(named: "Earth"))
    let expectedEarth = try snapshot.stateProvider!.state(for: .earth, at: epoch)
    #expect(simd_distance(earth.preciseWorldPosition, expectedEarth.scenePosition) < 1e-12)
    if mission != .artemisII {
        let route = try #require(resources.navigationController.routeRenderState.route)
        #expect(route.missionEarthPreciseCenter == earth.preciseWorldPosition)
        #expect(route.crew13Profile?.normal == launchRoute.crew13Profile?.normal)
        #expect(route.starshipProfile?.normal == launchRoute.starshipProfile?.normal)
    }
    resources.navigationController.beginManualCameraControl()
    resources.sceneCoordinator.setPresentationActive(false)
    wallDate.addTimeInterval(3_600)
    resources.sceneCoordinator.update(deltaTime: 3_600)
    resources.sceneCoordinator.setPresentationActive(true)
    resources.sceneCoordinator.update(deltaTime: 3_600)
    #expect(resources.sceneCoordinator.latestFrameState?.simulationTime == epoch)
    #expect(resources.navigationSnapshot.elapsedTime == 4)
    #expect(!resources.navigationController.routeRenderState.isCameraAutoFramingEnabled)
    resources.sceneCoordinator.update(deltaTime: timeline.duration - 4)
    #expect(resources.navigationSnapshot.state == .completed)
    #expect(resources.navigationSnapshot.elapsedTime == timeline.duration)
    #expect(resources.sceneCoordinator.latestFrameState?.simulationTime == timeline.arrivalEpoch)
    #expect(resources.simulationSnapshot.dateUTC == SimulationTime.date(forTDBSeconds: timeline.arrivalEpoch))
    resources.sceneCoordinator.update(deltaTime: 0.1)
    #expect(resources.sceneCoordinator.latestFrameState?.simulationTime == timeline.arrivalEpoch)
    resources.navigation.doneNavigation()
    #expect(resources.simulationSnapshot.mode == .live)
    #expect(abs(resources.simulationSnapshot.dateUTC.timeIntervalSince(wallDate)) < 0.001)
    resources.navigation.startMission(mission)
    #expect(resources.navigationSnapshot.routeID != routeID)
    #expect(resources.navigationSnapshot.elapsedTime == 0)
    #expect(resources.snapshotProvider.latestSnapshot?.simulationTime == timeline.departureEpoch)
    resources.navigation.cancelNavigation()
    #expect(resources.navigationController.activeMissionReplay == nil)
    #expect(resources.simulationSnapshot.mode == .live)
}

private struct MissionRestrictedProvider: CelestialStateProviding {
    let archive: EphemerisArchive
    let blockedEpoch: Double

    func state(for body: CelestialBodyID, at seconds: Double) throws -> CelestialBodyState {
        if abs(seconds - blockedEpoch) < 1 { throw CelestialStateError.outsideCoverage }
        return try archive.state(for: body, at: seconds)
    }
}

@MainActor
@Test(arguments: [0, 1])
func missionRejectsMissingLaunchOrFutureEphemerisAndRetries(anchorIndex: Int) throws {
    let archive = try EphemerisArchive.bundled.get()
    let timeline = MissionTimeline.forMission(.artemisII)
    let provider = MissionRestrictedProvider(archive: archive, blockedEpoch: timeline.anchors[anchorIndex].epoch)
    let now = missionDate("2026-10-16T10:00:00Z")
    let resources = try missionResources(stateProvider: provider, now: { now })
    resources.navigation.startMission(.artemisII)
    #expect(resources.navigationSnapshot.state == .failed)
    #expect(resources.navigationSnapshot.failure == .ephemerisUnavailable)
    #expect(resources.navigationSnapshot.mission == .artemisII)
    #expect(resources.navigationController.activeMissionReplay == nil)
    #expect(resources.simulationSnapshot.mode == .live)
    resources.sceneSnapshotPipeline.setStateProvider(archive)
    resources.navigation.startMission(.artemisII)
    #expect(resources.navigationSnapshot.state == .running)
    #expect(resources.simulationSnapshot.mode == .missionReplay)
    resources.navigation.cancelNavigation()
}

@MainActor
@Test func missionReplacementAndTransferSwitchResetSharedClock() throws {
    let now = missionDate("2026-10-16T10:00:00Z")
    let resources = try missionResources(now: { now })
    resources.navigation.startMission(.starshipFlight14)
    resources.sceneCoordinator.update(deltaTime: 30)
    resources.navigation.startMission(.crew13)
    #expect(resources.navigationSnapshot.elapsedTime == 0)
    #expect(resources.navigationController.routeRenderState.starshipFlight == nil)
    resources.sceneCoordinator.update(deltaTime: 5)
    #expect(resources.sceneCoordinator.latestFrameState?.simulationTime
            == MissionTimeline.forMission(.crew13).epoch(at: 5))
    resources.navigation.startNavigation(to: "Mars")
    let transfer = try #require(resources.navigationController.activeTransfer)
    #expect(abs(transfer.departureEpoch - SimulationTime.tdbSeconds(for: now)) < 1e-6)
    resources.sceneCoordinator.update(deltaTime: 15)
    #expect(resources.simulationSnapshot.mode == .transferPreview)
    #expect(abs(resources.navigationSnapshot.progress - 0.5) < 1e-6)
    resources.navigation.startMission(.artemisII)
    resources.sceneCoordinator.update(deltaTime: 1)
    #expect(resources.navigationController.activeTransfer == nil)
    #expect(resources.simulationSnapshot.mode == .missionReplay)
    #expect(resources.navigationSnapshot.elapsedTime == 1)
    resources.navigation.cancelNavigation()
}

@MainActor
@Test func artemisEncounterAndReturnKeepStableParametersInTheMovingScene() throws {
    let resources = try missionResources()
    resources.navigation.startMission(.artemisII)
    let timeline = MissionTimeline.forMission(.artemisII)
    let encounterTime = timeline.anchors[1].playbackTime
    resources.sceneCoordinator.update(deltaTime: encounterTime)
    #expect(abs(resources.navigationSnapshot.progress - 0.58) < 1e-6)
    let route = try #require(resources.navigationController.routeRenderState.route)
    let moon = try #require(resources.snapshotProvider.latestSnapshot?.planet(named: "Moon"))
    let marker = try #require(route.precisePoint(at: 0.58))
    let clearance = simd_distance(marker, moon.preciseWorldPosition)
    let nearest = try #require(route.precisePoints.map { simd_distance($0, moon.preciseWorldPosition) }.min())
    #expect(abs(clearance - nearest) < 1e-6)
    #expect(clearance > Double(moon.surfaceRadius) * 1.05)
    #expect(resources.sceneCoordinator.latestFrameState?.simulationTime == timeline.anchors[1].epoch)
    let parameters = try #require(route.sampleProgresses)
    #expect(parameters.count == route.precisePoints.count)
    #expect(zip(parameters, parameters.dropFirst()).allSatisfy { $0 < $1 })
    for boundary in [ArtemisRouteProfile.openingPhaseEnd(estimatedDuration: 16), 0.48, 0.58, 0.7] {
        let before = try #require(route.precisePoint(at: boundary - 1e-6))
        let after = try #require(route.precisePoint(at: boundary + 1e-6))
        #expect(simd_distance(before, after) < 0.0001)
    }
    resources.navigation.startMission(.artemisII)
    for _ in 0..<320 {
        resources.sceneCoordinator.update(deltaTime: 0.05)
        let state = resources.navigationController.routeRenderState
        let currentRoute = try #require(state.route)
        let earth = try #require(resources.snapshotProvider.latestSnapshot?.planet(named: "Earth"))
        let point = try #require(currentRoute.precisePoint(at: state.progress))
        #expect(simd_distance(point, earth.preciseWorldPosition) >= Double(earth.surfaceRadius) - 1e-8)
    }
    #expect(resources.navigationSnapshot.state == .completed)
    let finalRoute = try #require(resources.navigationController.routeRenderState.route)
    let finalEarth = try #require(resources.snapshotProvider.latestSnapshot?.planet(named: "Earth"))
    let endpoint = try #require(finalRoute.precisePoint(at: 1))
    #expect(abs(simd_distance(endpoint, finalEarth.preciseWorldPosition) - Double(finalEarth.surfaceRadius)) < 1e-8)
    resources.navigation.cancelNavigation()
}

@MainActor
@Test func pendingMissionWaitsForMetricsAtItsHistoricalLaunchEpoch() throws {
    let now = missionDate("2026-10-16T10:00:00Z")
    let resources = UniverseModuleResources(stateProvider: try EphemerisArchive.bundled.get(), now: { now })
    resources.setViewportSize(CGSize(width: 402, height: 874))
    resources.navigation.startMission(.crew13)
    #expect(resources.navigationSnapshot.state == .preparing)
    resources.sceneCoordinator.update(deltaTime: 5)
    let start = MissionTimeline.forMission(.crew13).departureEpoch
    #expect(resources.snapshotProvider.latestSnapshot?.simulationTime == start)
    #expect(resources.navigationSnapshot.state == .preparing)
    resources.sceneSnapshotPipeline.setPresentationMetrics(Dictionary(uniqueKeysWithValues: resources.planets.map {
        ($0.name, CelestialBodyPresentationMetrics(renderRadius: $0.radius,
                                                   framingRadius: $0.radius, surfaceRadius: $0.radius))
    }))
    resources.sceneCoordinator.update(deltaTime: 0.5)
    #expect(resources.navigationSnapshot.state == .running)
    #expect(resources.navigationSnapshot.elapsedTime == 0)
    #expect(resources.snapshotProvider.latestSnapshot?.simulationTime == start)
    resources.sceneCoordinator.update(deltaTime: 1)
    #expect(resources.navigationSnapshot.elapsedTime == 1)
    resources.navigation.cancelNavigation()
}

@MainActor
@Test func missionRuntimeEphemerisFailureClearsReplayAndRestoresLive() throws {
    let now = missionDate("2026-10-16T10:00:00Z")
    let archive = try EphemerisArchive.bundled.get()
    let blocked = MissionTimeline.forMission(.crew13).epoch(at: 4)
    let resources = try missionResources(stateProvider: MissionRestrictedProvider(archive: archive,
                                         blockedEpoch: blocked),
                                         now: { now })
    resources.navigation.startMission(.crew13)
    #expect(resources.navigationSnapshot.state == .running)
    resources.sceneCoordinator.update(deltaTime: 4)
    #expect(resources.navigationSnapshot.state == .failed)
    #expect(resources.navigationSnapshot.mission == .crew13)
    #expect(resources.navigationSnapshot.failure == .ephemerisUnavailable)
    #expect(resources.navigationController.routeRenderState.route == nil)
    #expect(resources.navigationController.activeMissionReplay == nil)
    #expect(resources.simulationSnapshot.mode == .live)
    #expect(resources.snapshotProvider.latestSnapshot?.simulationTime == SimulationTime.tdbSeconds(for: now))
    resources.sceneCoordinator.update(deltaTime: 0)
    #expect(resources.sceneCoordinator.latestFrameState?.routes.navigation.route == nil)
}

@MainActor
private func requireDatedMissionLaunch(resources: UniverseModuleResources,
                                       mission: MissionFlightPlan) throws -> NavigationRoute {
    let launchEarth = try #require(resources.snapshotProvider.latestSnapshot?.planet(named: "Earth"))
    let launchRoute = try #require(resources.navigationController.routeRenderState.route)
    if mission == .crew13 {
        #expect(launchRoute.crew13Profile == Crew13RouteProfile(earth: launchEarth))
    } else if mission == .starshipFlight14 {
        #expect(launchRoute.starshipProfile == StarshipRouteProfile(earth: launchEarth))
    }
    return launchRoute
}
