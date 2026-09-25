import CoreGraphics
import simd
import Testing
@testable import UniverseModule

@MainActor
@Test func previewPublishesEllipsesAndArrivalState() async throws {
    let fixture = TransferFixture()
    fixture.controller.showTransferOrbit(to: "Mars")
    #expect(fixture.controller.previewSnapshot.status == .preparing)
    try await fixture.settle()
    #expect(fixture.controller.previewSnapshot.status == .ready)
    let solution = try #require(fixture.controller.renderState.transferOrbit)
    #expect(solution.destinationOrbitPoints.contains { abs($0.y) > 1 })
    #expect(fixture.controller.previewSnapshot.physicalFlightDuration == solution.flightDuration)
    fixture.controller.update(snapshot: fixture.source.latestSnapshot, delta: 2)
    #expect(fixture.camera.cameraTarget == .zero)
}

@MainActor
@Test func failedPreviewRetainsGuidesAndCanBeRetried() async throws {
    let fixture = TransferFixture()
    fixture.controller.showTransferOrbit(to: "Earth")
    try await fixture.settle()
    #expect(fixture.controller.previewSnapshot.status == .failed(.invalidGeometry))
    #expect(!fixture.controller.renderState.earthOrbitPoints.isEmpty)
    #expect(!fixture.controller.renderState.destinationOrbitPoints.isEmpty)
    #expect(fixture.controller.renderState.transferOrbit == nil)
    fixture.controller.showTransferOrbit(to: "Mars")
    try await fixture.settle()
    #expect(fixture.controller.previewSnapshot.status == .ready)
}

@MainActor
@Test func previewDiscardsResultsAfterDestinationChangeOrClose() async throws {
    let fixture = TransferFixture()
    fixture.controller.showTransferOrbit(to: "Mars")
    fixture.controller.showTransferOrbit(to: "Neptune")
    try await fixture.settle()
    #expect(fixture.controller.renderState.transferOrbit?.destinationName == "Neptune")
    fixture.controller.showTransferOrbit(to: "Venus")
    fixture.controller.clearTransferOrbit()
    try await Task.sleep(for: .milliseconds(100))
    #expect(fixture.controller.renderState == .inactive)
    #expect(fixture.controller.previewSnapshot == .inactive)
}

@MainActor
@Test func outerPlanetPreviewFramesFullEllipseAndTransfer() async throws {
    let fixture = TransferFixture()
    fixture.controller.showTransferOrbit(to: "Pluto")
    try await fixture.settle()
    let transfer = try #require(fixture.controller.renderState.transferOrbit)
    let dependency = try #require(fixture.controller.cameraSnapshotDependency)
    #expect(try #require(dependency.maximumCameraDistance) > transfer.framingRadius)
    let projection = fixture.controller.projectionParameters(snapshot: fixture.source.latestSnapshot,
                                                              baseProjection: CameraProjectionParameters(nearPlane: 0.001, farPlane: 10_000))
    #expect(projection.farPlane > transfer.framingRadius * 2)
}

@MainActor
private struct TransferFixture {
    let source: TransferSource
    let camera: CameraState
    let controller: TransferOrbitController
    // The controller's dependencies are unowned, so keep their owners alive in the fixture.
    let provider: SnapshotProvider
    let cameraCoordinator: CameraCoordinator

    init() {
        source = TransferSource(snapshot: orbitalTestSnapshot())
        camera = CameraState()
        provider = SnapshotProvider(cameraState: camera, snapshotSource: source)
        cameraCoordinator = CameraCoordinator(cameraState: camera, snapshotProvider: provider)
        controller = TransferOrbitController(snapshotProvider: provider, cameraCoordinator: cameraCoordinator,
                                             planets: testPlanets, viewportSize: { CGSize(width: 390, height: 844) })
    }

    func settle() async throws {
        for _ in 0..<200 {
            controller.update(snapshot: source.latestSnapshot, delta: 0.25)
            if controller.previewSnapshot.status != .preparing { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        Issue.record("Transfer preview timed out")
    }
}

@MainActor
private final class TransferSource: UniverseSceneSnapshotProviding {
    var latestSnapshot: UniverseSceneSnapshot?
    init(snapshot: UniverseSceneSnapshot) { latestSnapshot = snapshot }
    func requestPreparation(simulationTime: Double) {}
}
