import Foundation
import simd
import Testing
@testable import UniverseModule

private struct EphemerisReferences: Decodable {
    struct Time: Decodable {
        let utc: String
        let seconds: Double
    }
    struct State: Decodable {
        let body: CelestialBodyID
        let seconds: Double
        let position: [Double]
        let velocity: [Double]
        let orientation: [Double]
    }
    let times: [Time]
    let states: [State]

    static func load() throws -> Self {
        let url = try #require(Bundle.module.url(forResource: "ephemeris_references", withExtension: "json"))
        return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }
}

@Test func offlineStatesMatchIndependentHorizonsAndSpiceReferences() throws {
    let archive = try EphemerisArchive.bundled.get()
    let references = try EphemerisReferences.load()
    #expect(Set(references.states.map(\.body)) == Set(CelestialBodyID.allCases))
    for reference in references.states {
        let state = try archive.state(for: reference.body, at: reference.seconds)
        let position = SIMD3(reference.position[0], reference.position[1], reference.position[2])
        let velocity = SIMD3(reference.velocity[0], reference.velocity[1], reference.velocity[2])
        #expect(simd_distance(state.positionKm, position) < 10)
        #expect(simd_distance(state.velocityKmPerSecond, velocity) < 0.001)
        for column in 0..<3 {
            for row in 0..<3 {
                #expect(abs(state.bodyFixedToEcliptic[column][row] - reference.orientation[column*3+row]) < 1e-10)
            }
        }
        let identity = state.bodyFixedToEcliptic.transpose * state.bodyFixedToEcliptic
        #expect(simd_length(identity.columns.0 - SIMD3(1, 0, 0)) < 1e-12)
        #expect(abs(simd_determinant(state.bodyFixedToEcliptic) - 1) < 1e-12)
    }
}

@Test func utcAndTDBMatchSpiceIncludingLeapBoundaryAndFutureDates() throws {
    let formatter = ISO8601DateFormatter()
    for reference in try EphemerisReferences.load().times {
        let date = try #require(formatter.date(from: reference.utc))
        #expect(abs(SimulationTime.tdbSeconds(for: date) - reference.seconds) < 0.0001)
        #expect(abs(SimulationTime.date(forTDBSeconds: reference.seconds).timeIntervalSince(date)) < 0.0001)
    }
    let j2000UTC = SimulationTime.utcJ2000
    #expect(abs(SimulationTime.tdbSeconds(for: j2000UTC) - 64.1839273) < 0.0001)
}

@Test func archiveRejectsNonfiniteAndUncoveredEpochs() throws {
    let archive = try EphemerisArchive.bundled.get()
    for epoch in [Double.nan, Double.infinity, archive.startSeconds - 1, archive.endSeconds + 1] {
        #expect(throws: CelestialStateError.outsideCoverage) {
            try archive.state(for: .earth, at: epoch)
        }
    }
}

@Test func hermiteInterpolationPreservesEndpointsAndVelocityDerivative() {
    let left = EphemerisArchive.Record(time: 0, position: SIMD3(1, 2, 3), velocity: SIMD3(4, 5, 6))
    let right = EphemerisArchive.Record(time: 10, position: SIMD3(7, 8, 9), velocity: SIMD3(1, 2, 3))
    #expect(EphemerisArchive.interpolate(left, right, at: 0).position == left.position)
    #expect(EphemerisArchive.interpolate(left, right, at: 10).velocity == right.velocity)
    let before = EphemerisArchive.interpolate(left, right, at: 5 - 0.0001).position
    let after = EphemerisArchive.interpolate(left, right, at: 5 + 0.0001).position
    #expect(simd_distance((after-before)/0.0002, EphemerisArchive.interpolate(left, right, at: 5).velocity) < 1e-8)
}

@Test func corruptOrientationIsRejectedBeforePublishingAnyStates() throws {
    let source = try #require(UniverseModuleAssets.ephemerisDirectory())
    let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporary) }
    try FileManager.default.copyItem(at: source.appendingPathComponent("manifest.json"),
                                    to: temporary.appendingPathComponent("manifest.json"))
    try Data("{}".utf8).write(to: temporary.appendingPathComponent("orientation.json"))
    #expect(throws: CelestialStateError.invalidData) { try EphemerisArchive.load(directory: temporary) }
}

@MainActor
@Test func liveClockTracksWallTimeAndAllowsBackwardCorrection() {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
    var clock = UniverseSimulationClock(now: { date })
    date.addTimeInterval(2)
    _ = clock.advance(by: 0.01)
    #expect(clock.currentTime == SimulationTime.tdbSeconds(for: date))
    #expect(clock.presentationTime == 0.01)
    date.addTimeInterval(-10)
    _ = clock.advance(by: 0)
    #expect(clock.currentTime == SimulationTime.tdbSeconds(for: date))
    #expect(clock.mode == .live)
}

@MainActor
@Test func surfaceAndCameraRetainLocalPrecisionAtPlutoDistance() throws {
    let center = SIMD3<Double>(6_000.123456789, -200.987654321, 5_000.876543219)
    let packet = CelestialBodySnapshot(planetName: "Pluto", baseModelMatrix: matrix_identity_float4x4,
                                       normalizedScale: 0.0012, framingRadius: 0.0012, surfaceRadius: 0.0012,
                                       worldPosition: SIMD3<Float>(center), preciseWorldPosition: center)
    let coordinate = SurfaceCoordinate(latitudeDegrees: 25, longitudeDegrees: 97)
    let point = SurfaceCoordinateMath.preciseWorldSurfacePoint(on: packet, at: coordinate)
    let recovered = try #require(SurfaceCoordinateMath.coordinate(on: packet, forPreciseWorldPoint: point))
    #expect(abs(recovered.latitudeDegrees - coordinate.latitudeDegrees) < 0.0001)
    #expect(abs(recovered.longitudeDegrees - coordinate.longitudeDegrees) < 0.0001)
    let camera = CameraState()
    camera.commit(.init(preciseCameraTarget: center))
    #expect(camera.pose.preciseTarget == center)
    let rendered = EphemerisCoordinates.renderPosition(point, relativeTo: camera.pose.preciseTarget)
    #expect(abs(simd_length(rendered) - packet.surfaceRadius) < 1e-9)
}

@MainActor
@Test func physicalTransfersUseEphemerisEndpointsAndReportMissingCoverage() throws {
    let archive = try EphemerisArchive.bundled.get()
    let departure = SimulationTime.tdbSeconds(for: Date(timeIntervalSince1970: 1_800_000_000))
    let transfer = try TransferSolution.make(destinationName: "Mars", planets: testPlanets,
                                             departureEpoch: departure, stateProvider: archive)
    let earth = try archive.state(for: .earth, at: departure)
    let mars = try archive.state(for: .mars, at: transfer.arrivalEpoch)
    #expect(simd_distance(transfer.trajectory.initialPosition, earth.positionKm) < 0.001)
    #expect(simd_distance(try transfer.trajectory.state(after: transfer.flightDuration).position, mars.positionKm) < 10)
    #expect(throws: TransferFailure.ephemerisUnavailable) {
        try TransferSolution.make(destinationName: "Mars", planets: testPlanets,
                                  departureEpoch: archive.endSeconds - 1, stateProvider: archive)
    }
    for name in ["Uranus", "Neptune", "Pluto"] {
        let outer = try TransferSolution.make(destinationName: name, planets: testPlanets,
                                              departureEpoch: departure, stateProvider: archive)
        #expect(outer.hasPartialDestinationOrbit == (name != "Uranus"))
        #expect(outer.preciseDestinationOrbitPoints.count == 257)
        let body = try #require(CelestialBodyID(rawValue: name))
        let target = try archive.state(for: body, at: outer.arrivalEpoch)
        #expect(simd_distance(try outer.trajectory.state(after: outer.flightDuration).position, target.positionKm) < 10)
    }
}

@MainActor
@Test func manualMissionCameraTracksSubKilometerLiveMotion() throws {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
    let resources = UniverseModuleResources(stateProvider: try EphemerisArchive.bundled.get(), now: { date })
    resources.setViewportSize(CGSize(width: 390, height: 844))
    resources.sceneSnapshotPipeline.setPresentationMetrics(Dictionary(uniqueKeysWithValues: testPlanets.map {
        ($0.name, CelestialBodyPresentationMetrics(renderRadius: $0.radius,
                                                   framingRadius: $0.radius, surfaceRadius: $0.radius))
    }))
    resources.sceneCoordinator.update(deltaTime: 0)
    resources.navigation.startMission(.crew13)
    resources.sceneCoordinator.update(deltaTime: 60)
    resources.beginManualCameraControl()
    let beforeMarker = try #require(resources.navigationController.routeRenderState.route?.precisePoint(at: 1))
    let beforeTarget = resources.cameraState.preciseCameraTarget
    date.addTimeInterval(0.016)
    resources.sceneCoordinator.update(deltaTime: 0.016)
    let afterMarker = try #require(resources.navigationController.routeRenderState.route?.precisePoint(at: 1))
    #expect(simd_distance(beforeMarker, afterMarker) > 0)
    #expect(simd_distance(beforeMarker, afterMarker) < 1e-6)
    #expect(simd_distance(beforeTarget - beforeMarker, resources.cameraState.preciseCameraTarget - afterMarker) < 1e-10)
}

@MainActor
@Test func acceleratedDateIndicatorUpdatesOncePerActiveSecondAndModeChangesImmediately() throws {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let resources = UniverseModuleResources(stateProvider: try EphemerisArchive.bundled.get(), now: { date })
    resources.setViewportSize(CGSize(width: 390, height: 844))
    resources.sceneSnapshotPipeline.setPresentationMetrics(Dictionary(uniqueKeysWithValues: testPlanets.map {
        ($0.name, CelestialBodyPresentationMetrics(renderRadius: $0.radius,
                                                   framingRadius: $0.radius, surfaceRadius: $0.radius))
    }))
    resources.sceneCoordinator.update(deltaTime: 0)
    resources.navigation.startNavigation(to: "Mars")
    resources.sceneCoordinator.update(deltaTime: 0.1)
    let initialPreview = resources.simulationSnapshot
    #expect(initialPreview.mode == .transferPreview)
    resources.sceneCoordinator.update(deltaTime: 0.1)
    #expect(resources.simulationSnapshot == initialPreview)
    resources.sceneCoordinator.update(deltaTime: 1)
    #expect(resources.simulationSnapshot.dateUTC > initialPreview.dateUTC)
    resources.navigation.cancelNavigation()
    #expect(resources.simulationSnapshot.mode == .live)
    #expect(abs(resources.simulationSnapshot.dateUTC.timeIntervalSince(date)) < 0.0001)
}
