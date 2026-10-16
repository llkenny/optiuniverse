import Foundation
import simd
import Testing
@testable import UniverseModule

@MainActor
@Test func navigationControllerStartsRouteAndExposesRenderState() throws {
    let fixture = NavigationControllerFixture()

    fixture.controller.startNavigation(to: "Mars")

    #expect(fixture.controller.navigationSnapshot.state == .running)
    #expect(fixture.controller.routeRenderState.route?.destinationName == "Mars")
    #expect(fixture.controller.routeRenderState.progress < 0.001)
}

@MainActor
@Test func navigationControllerStartsContinuousEarthMoonEarthNavigation() throws {
    let fixture = NavigationControllerFixture(snapshot: .cislunarNavigationControllerTestSnapshot)

    fixture.controller.startNavigation(from: "Earth", via: "Moon", to: "Earth")

    let route = try #require(fixture.controller.routeRenderState.route)
    #expect(fixture.controller.navigationSnapshot.state == .running)
    #expect(fixture.controller.navigationSnapshot.originName == "Earth")
    #expect(fixture.controller.navigationSnapshot.waypointName == "Moon")
    #expect(fixture.controller.navigationSnapshot.destinationName == "Earth")
    #expect(route.originName == "Earth")
    #expect(route.waypointName == "Moon")
    #expect(route.destinationName == "Earth")
    #expect(route.estimatedDuration == 16)
}

@MainActor
@Test func navigationControllerPublishesPreparingSnapshotForPendingMissionNavigation() throws {
    let fixture = NavigationControllerFixture(snapshot: nil)

    fixture.controller.startNavigation(from: "Earth", via: "Moon", to: "Earth")

    #expect(fixture.controller.navigationSnapshot.state == .preparing)
    #expect(fixture.controller.navigationSnapshot.originName == "Earth")
    #expect(fixture.controller.navigationSnapshot.waypointName == "Moon")
    #expect(fixture.controller.navigationSnapshot.destinationName == "Earth")
    #expect(fixture.controller.routeRenderState.route == nil)
}

@MainActor
@Test func navigationControllerAppliesPendingMissionNavigationWhenSnapshotArrives() throws {
    let fixture = NavigationControllerFixture(snapshot: nil)

    fixture.controller.startNavigation(from: "Earth", via: "Moon", to: "Earth")
    fixture.source.latestSnapshot = .cislunarNavigationControllerTestSnapshot
    fixture.controller.update(snapshot: .cislunarNavigationControllerTestSnapshot,
                              delta: 0.1)

    let route = try #require(fixture.controller.routeRenderState.route)
    #expect(fixture.controller.navigationSnapshot.state == .running)
    #expect(route.originName == "Earth")
    #expect(route.waypointName == "Moon")
    #expect(route.destinationName == "Earth")
}

@MainActor
@Test func navigationControllerStartDoesNotMutateCameraState() {
    let fixture = NavigationControllerFixture()
    let initialRevision = fixture.cameraState.revision
    let initialPose = fixture.cameraState.pose

    fixture.controller.startNavigation(to: "Mars")

    #expect(fixture.cameraState.revision == initialRevision)
    #expect(fixture.cameraState.pose == initialPose)
}

@MainActor
@Test func navigationControllerCancelDoesNotMutateCameraState() {
    let fixture = NavigationControllerFixture()
    let initialRevision = fixture.cameraState.revision
    let initialPose = fixture.cameraState.pose

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.cancelNavigation()

    #expect(fixture.controller.navigationSnapshot.state == .cancelled)
    #expect(fixture.cameraState.revision == initialRevision)
    #expect(fixture.cameraState.pose == initialPose)
}

@MainActor
@Test func navigationControllerUpdateDoesNotMutateCameraState() {
    let fixture = NavigationControllerFixture()
    let initialRevision = fixture.cameraState.revision
    let initialPose = fixture.cameraState.pose

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.update(snapshot: fixture.snapshot,
                              delta: 0.1)

    #expect(fixture.cameraState.revision == initialRevision)
    #expect(fixture.cameraState.pose == initialPose)
}

@MainActor
@Test func navigationControllerUpdateKeepsRouteGeometryStableWhileProgressAdvances() throws {
    let playback = AdvancingRoutePlayback(progressAfterUpdate: 0.5)
    let fixture = NavigationControllerFixture(routePlayback: playback)

    fixture.controller.startNavigation(to: "Mars")
    let initialPoints = try #require(fixture.controller.routeRenderState.route?.points)

    fixture.updateTransfer(progress: 0.5)

    #expect(fixture.controller.routeRenderState.progress == 0.5)
    #expect(fixture.controller.routeRenderState.route?.points == initialPoints)
}

@MainActor
@Test func navigationControllerManualCameraControlDisablesAutoFramingButKeepsRouteActive() throws {
    let fixture = NavigationControllerFixture()

    fixture.controller.startNavigation(to: "Mars")
    #expect(fixture.controller.routeRenderState.isCameraAutoFramingEnabled)

    fixture.controller.beginManualCameraControl()

    #expect(!fixture.controller.routeRenderState.isCameraAutoFramingEnabled)
    #expect(fixture.controller.routeRenderState.route != nil)
    #expect(fixture.controller.navigationSnapshot.state == .running)
}

@MainActor
@Test func navigationControllerStartResetsCameraAutoFraming() throws {
    let fixture = NavigationControllerFixture()

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.beginManualCameraControl()
    #expect(!fixture.controller.routeRenderState.isCameraAutoFramingEnabled)

    fixture.controller.cancelNavigation()
    fixture.controller.startNavigation(to: "Mars")

    #expect(fixture.controller.routeRenderState.isCameraAutoFramingEnabled)
}

@MainActor
@Test func navigationControllerPublishesObservableFacadeStateChanges() {
    let fixture = NavigationControllerFixture()
    var snapshots: [NavigationRouteSnapshot] = []
    fixture.controller.navigationSnapshotDidChange = { snapshots.append($0) }

    fixture.controller.startNavigation(to: "Mars")

    #expect(snapshots.contains { $0.state == .running && $0.destinationName == "Mars" })
}

@MainActor
@Test func navigationControllerDoneDoesNotMutateCameraState() {
    let playback = CompletingRoutePlayback()
    let fixture = NavigationControllerFixture(routePlayback: playback)

    fixture.controller.startNavigation(to: "Mars")
    fixture.updateTransfer(progress: 1)
    let initialRevision = fixture.cameraState.revision
    let initialPose = fixture.cameraState.pose

    fixture.controller.doneNavigation()

    #expect(fixture.controller.navigationSnapshot.state == .cancelled)
    #expect(fixture.cameraState.revision == initialRevision)
    #expect(fixture.cameraState.pose == initialPose)
}

@MainActor
@Test func navigationControllerKeepsAutoFramingDuringCompletedHold() {
    let playback = CompletingRoutePlayback()
    let fixture = NavigationControllerFixture(routePlayback: playback)

    fixture.controller.startNavigation(to: "Mars")
    fixture.updateTransfer(progress: 1)

    #expect(fixture.controller.navigationSnapshot.state == .completed)
    #expect(fixture.controller.routeRenderState.isCameraAutoFramingEnabled)
    #expect(fixture.controller.routeRenderState.progress == 1)
}

@MainActor
@Test func navigationControllerDonePublishesCompletedDestinationHandoff() {
    let playback = CompletingRoutePlayback()
    let fixture = NavigationControllerFixture(routePlayback: playback)
    var completedDestinationName: String?
    fixture.controller.navigationDidComplete = { name, _ in completedDestinationName = name }

    fixture.controller.startNavigation(to: "Mars")
    fixture.updateTransfer(progress: 1)
    fixture.controller.doneNavigation()

    #expect(completedDestinationName == "Mars")
    #expect(fixture.controller.navigationSnapshot.state == .cancelled)
}

@MainActor
@Test func navigationControllerCancelDoesNotPublishCompletedDestinationHandoff() {
    let fixture = NavigationControllerFixture()
    var completedDestinationName: String?
    fixture.controller.navigationDidComplete = { name, _ in completedDestinationName = name }

    fixture.controller.startNavigation(to: "Mars")
    fixture.controller.cancelNavigation()

    #expect(completedDestinationName == nil)
}

@MainActor
@Test func starshipPendingRequestRetainsMissionAndCanBeCancelled() throws {
    let fixture = NavigationControllerFixture(snapshot: nil)
    fixture.controller.startMission(.starshipFlight14)
    #expect(fixture.controller.navigationSnapshot.state == .preparing)
    #expect(fixture.controller.navigationSnapshot.mission == .starshipFlight14)
    fixture.source.latestSnapshot = .navigationControllerTestSnapshot
    fixture.controller.update(snapshot: .navigationControllerTestSnapshot, delta: 0)
    #expect(fixture.controller.navigationSnapshot.state == .running)
    #expect(fixture.controller.navigationSnapshot.mission == .starshipFlight14)
    #expect(fixture.controller.routeRenderState.route?.transfer == nil)
    let firstID = fixture.controller.navigationSnapshot.routeID
    fixture.controller.cancelNavigation()
    fixture.controller.startMission(.starshipFlight14)
    #expect(fixture.controller.navigationSnapshot.routeID != firstID)
    #expect(fixture.controller.navigationSnapshot.elapsedTime == 0)
    fixture.controller.beginManualCameraControl()
    #expect(!fixture.controller.routeRenderState.isCameraAutoFramingEnabled)
    fixture.controller.cancelNavigation()
    #expect(fixture.controller.pendingNavigationRequest == nil)
    #expect(fixture.controller.routeRenderState.starshipFlight == nil)
}

@MainActor
@Test func starshipFailedStartCanRetrySameMission() {
    let fixture = NavigationControllerFixture(snapshot: UniverseSceneSnapshot(frameID: 0, simulationTime: 0,
                                              planets: []))
    fixture.controller.startMission(.starshipFlight14)
    #expect(fixture.controller.navigationSnapshot.state == .failed)
    #expect(fixture.controller.navigationSnapshot.mission == .starshipFlight14)
    fixture.source.latestSnapshot = .navigationControllerTestSnapshot
    fixture.controller.startMission(.starshipFlight14)
    #expect(fixture.controller.navigationSnapshot.state == .running)
    #expect(fixture.controller.navigationSnapshot.estimatedDuration == 60)
}

@MainActor
@Test func crew13PendingRequestAndRestartPreserveISSDestination() throws {
    let fixture = NavigationControllerFixture(snapshot: nil)
    fixture.controller.startMission(.crew13)
    #expect(fixture.controller.navigationSnapshot.state == .preparing)
    #expect(fixture.controller.navigationSnapshot.mission == .crew13)
    #expect(fixture.controller.navigationSnapshot.destinationName == "ISS")
    fixture.controller.cancelNavigation()
    #expect(fixture.controller.pendingNavigationRequest == nil)
    fixture.controller.startMission(.crew13)
    fixture.source.latestSnapshot = .navigationControllerTestSnapshot
    fixture.controller.update(snapshot: .navigationControllerTestSnapshot, delta: 0)
    #expect(fixture.controller.navigationSnapshot.state == .running)
    #expect(fixture.controller.navigationSnapshot.destinationName == "ISS")
    #expect(fixture.controller.routeRenderState.route?.transfer == nil)
    let firstID = try #require(fixture.controller.navigationSnapshot.routeID)
    fixture.controller.beginManualCameraControl()
    #expect(!fixture.controller.routeRenderState.isCameraAutoFramingEnabled)
    fixture.controller.startMission(.starshipFlight14)
    #expect(fixture.controller.routeRenderState.crew13Flight == nil)
    #expect(fixture.controller.routeRenderState.starshipFlight != nil)
    fixture.controller.startMission(.crew13)
    #expect(fixture.controller.navigationSnapshot.routeID != firstID)
    #expect(fixture.controller.navigationSnapshot.elapsedTime == 0)
    #expect(fixture.controller.routeRenderState.isCameraAutoFramingEnabled)
    fixture.controller.cancelNavigation()
    #expect(fixture.controller.routeRenderState.crew13Flight == nil)
}

@MainActor
@Test func crew13FailedStartRetriesAfterEarthBecomesAvailable() {
    let fixture = NavigationControllerFixture(snapshot: UniverseSceneSnapshot(frameID: 0, simulationTime: 0,
                                              planets: []))
    fixture.controller.startMission(.crew13)
    #expect(fixture.controller.navigationSnapshot.state == .failed)
    #expect(fixture.controller.navigationSnapshot.mission == .crew13)
    #expect(fixture.controller.navigationSnapshot.failure == .invalidGeometry)
    fixture.source.latestSnapshot = .navigationControllerTestSnapshot
    fixture.controller.startMission(.crew13)
    #expect(fixture.controller.navigationSnapshot.state == .running)
    #expect(fixture.controller.navigationSnapshot.estimatedDuration == 60)
}
