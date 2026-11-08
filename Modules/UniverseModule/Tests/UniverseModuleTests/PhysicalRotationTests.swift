import CoreGraphics
import Foundation
import RealityKit
import simd
import Testing
@testable import UniverseModule

@MainActor
private func rotationResources(now: @escaping () -> Date) throws -> UniverseModuleResources {
    let resources = UniverseModuleResources(stateProvider: try EphemerisArchive.bundled.get(), now: now)
    resources.setViewportSize(CGSize(width: 390, height: 844))
    resources.sceneSnapshotPipeline.setPresentationMetrics(Dictionary(uniqueKeysWithValues: resources.planets.map {
        ($0.name, CelestialBodyPresentationMetrics(renderRadius: $0.radius,
                                                   framingRadius: $0.radius, surfaceRadius: $0.radius))
    }))
    resources.sceneCoordinator.update(deltaTime: 0)
    return resources
}

private func expectRotationMatrix(_ actual: float4x4, equals expected: float4x4) {
    for column in 0..<4 {
        #expect(simd_length(actual[column] - expected[column]) < 0.000_002)
    }
}

/// Check the complete epoch-to-entity path without loading meshes or waiting three wall minutes.
@MainActor
@Test func livePhysicalRotationReachesEveryBodyAndPreservesFollowCamera() throws {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
    let resources = try rotationResources(now: { date })
    resources.followPlanet(named: "Earth")
    resources.sceneCoordinator.update(deltaTime: 2)
    #expect(!resources.cameraCoordinator.followCameraOwner.hasActiveTransition)
    let cameraOrientation = resources.cameraState.cameraOrientation
    let before = try #require(resources.snapshotProvider.latestSnapshot)
    date.addTimeInterval(180)
    // Live time follows the injected date, independently of the frame's presentation delta.
    resources.sceneCoordinator.update(deltaTime: 1.0 / 60)
    let after = try #require(resources.snapshotProvider.latestSnapshot)
    #expect(after.simulationTime == SimulationTime.tdbSeconds(for: date))
    #expect(after.planets.count == CelestialBodyID.allCases.count)
    #expect(resources.cameraState.cameraOrientation == cameraOrientation)
    #expect(resources.cameraState.preciseCameraTarget == after.planet(named: "Earth")?.preciseWorldPosition)

    for body in CelestialBodyID.allCases {
        let first = try #require(before.planet(named: body.rawValue))
        let last = try #require(after.planet(named: body.rawValue))
        let expected = try resources.sceneSnapshotPipeline.stateProvider.state(for: body, at: after.simulationTime)
        let entity = try #require(resources.sceneCoordinator.bodyEntities[body.rawValue])
        expectRotationMatrix(last.visualRotationMatrix, equals: expected.sceneOrientation)
        expectRotationMatrix(last.baseModelMatrix, equals: last.orbitTransformMatrix * expected.sceneOrientation)
        expectRotationMatrix(entity.rotationTransform.transform.matrix, equals: expected.sceneOrientation)
        #expect(simd_length(last.visualRotationMatrix[0] - first.visualRotationMatrix[0]) > 0.000_001)

        // Compare in the body's local frame so axial tilt cannot obscure retrograde direction.
        let relative = first.visualRotationMatrix.inverse * last.visualRotationMatrix
        let degrees = atan2(relative[2].x, relative[0].x) * 180 / Float.pi
        if body == .earth { #expect(abs(degrees - 0.752) < 0.002) }
        if body == .jupiter { #expect(abs(degrees - 1.814) < 0.002) }
        if body == .venus || body == .uranus { #expect(degrees < 0) }
    }

    resources.followPlanet(named: "Jupiter")
    resources.sceneCoordinator.update(deltaTime: 2)
    let selected = try #require(resources.snapshotProvider.latestSnapshot?.planet(named: "Jupiter"))
    let expected = try resources.sceneSnapshotPipeline.stateProvider.state(for: .jupiter, at: after.simulationTime)
    expectRotationMatrix(selected.visualRotationMatrix, equals: expected.sceneOrientation)
}

@MainActor
@Test func livePhysicalRotationRefreshesAfterBackgroundWithoutAdvancingPresentation() throws {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
    let resources = try rotationResources(now: { date })
    let before = try #require(resources.sceneCoordinator.latestFrameState)
    resources.sceneCoordinator.setPresentationActive(false)
    date.addTimeInterval(180)
    resources.sceneCoordinator.update(deltaTime: 180)
    #expect(resources.sceneCoordinator.latestFrameState?.snapshot?.frameID == before.snapshot?.frameID)
    resources.sceneCoordinator.setPresentationActive(true)
    resources.sceneCoordinator.update(deltaTime: 180)
    let resumed = try #require(resources.sceneCoordinator.latestFrameState)
    #expect(resumed.presentationTime == before.presentationTime)
    #expect(resumed.simulationTime == SimulationTime.tdbSeconds(for: date))
    let earth = try #require(resources.sceneCoordinator.bodyEntities["Earth"])
    let expected = try resources.sceneSnapshotPipeline.stateProvider.state(for: .earth, at: resumed.simulationTime)
    expectRotationMatrix(earth.rotationTransform.transform.matrix, equals: expected.sceneOrientation)
}

@MainActor
@Test(arguments: [SimulationMode.transferPreview, .missionReplay])
func playbackPhysicalRotationUsesSharedEpochAndRestoresLive(mode: SimulationMode) throws {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    let resources = try rotationResources(now: { date })
    if mode == .missionReplay {
        resources.navigation.startMission(.crew13)
    } else {
        resources.navigation.startNavigation(to: "Mars")
    }
    resources.sceneCoordinator.update(deltaTime: 4)
    #expect(resources.simulationSnapshot.mode == mode)
    let frame = try #require(resources.sceneCoordinator.latestFrameState)
    #expect(abs(frame.simulationTime - SimulationTime.tdbSeconds(for: date)) > 180)
    for body in CelestialBodyID.allCases {
        let packet = try #require(frame.snapshot?.planet(named: body.rawValue))
        let entity = try #require(resources.sceneCoordinator.bodyEntities[body.rawValue])
        let expected = try resources.sceneSnapshotPipeline.stateProvider.state(for: body, at: frame.simulationTime)
        expectRotationMatrix(packet.visualRotationMatrix, equals: expected.sceneOrientation)
        expectRotationMatrix(entity.rotationTransform.transform.matrix, equals: expected.sceneOrientation)
    }
    resources.navigation.cancelNavigation()
    resources.sceneCoordinator.update(deltaTime: 0)
    #expect(resources.simulationSnapshot.mode == .live)
    let liveEpoch = SimulationTime.tdbSeconds(for: date)
    #expect(resources.sceneCoordinator.latestFrameState?.simulationTime == liveEpoch)
    let expected = try resources.sceneSnapshotPipeline.stateProvider.state(for: .earth, at: liveEpoch)
    let earth = try #require(resources.sceneCoordinator.bodyEntities["Earth"])
    expectRotationMatrix(earth.rotationTransform.transform.matrix, equals: expected.sceneOrientation)
}

@MainActor
@Test func syntheticPipelineKeepsProviderOrientationWhenProviderIsReplaced() throws {
    let pipeline = UniverseSceneSnapshotPipeline(planets: testPlanets)
    pipeline.setPresentationMetrics(Dictionary(uniqueKeysWithValues: testPlanets.map {
        ($0.name, CelestialBodyPresentationMetrics(renderRadius: $0.radius,
                                                   framingRadius: $0.radius, surfaceRadius: $0.radius))
    }))
    let epoch = SimulationTime.tdbSeconds(for: Date(timeIntervalSince1970: 1_800_000_000))
    pipeline.requestPreparation(simulationTime: epoch)
    let synthetic = try #require(pipeline.latestSnapshot?.planet(named: "Earth"))
    expectRotationMatrix(synthetic.visualRotationMatrix, equals: matrix_identity_float4x4)
    let archive = try EphemerisArchive.bundled.get()
    pipeline.setStateProvider(archive)
    pipeline.requestPreparation(simulationTime: epoch)
    let physical = try #require(pipeline.latestSnapshot?.planet(named: "Earth"))
    let expected = try archive.state(for: .earth, at: epoch)
    expectRotationMatrix(physical.visualRotationMatrix, equals: expected.sceneOrientation)
}
