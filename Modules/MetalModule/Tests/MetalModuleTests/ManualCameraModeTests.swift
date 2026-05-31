import CoreGraphics
import Foundation
import simd
import Testing
@testable import MetalModule

@Test func orbitCameraModeProducesOrientationTransaction() throws {
    let mode = OrbitCameraMode()
    let initialOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))

    let transaction = mode.makeOrbitTransaction(horizontal: 0.2,
                                                vertical: -0.1,
                                                cameraOrientation: initialOrientation)

    let orientation = try #require(transaction.cameraOrientation)
    #expect(abs(simd_length(orientation.vector) - 1) < 0.000001)
    #expect(abs(simd_dot(orientation.vector, initialOrientation.vector)) < 0.999)
}

@Test func orbitCameraModeInertiaProducesOptionalTransaction() throws {
    let mode = OrbitCameraMode()
    let initialOrientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))

    let idleTransaction = mode.update(delta: 1.0 / 60.0,
                                      cameraOrientation: initialOrientation)
    let idleTransactionIsNil: Bool
    if case nil = idleTransaction {
        idleTransactionIsNil = true
    } else {
        idleTransactionIsNil = false
    }
    #expect(idleTransactionIsNil)

    mode.addInertia(velocity: CGPoint(x: 120, y: -80))
    let transaction = try #require(mode.update(delta: 1.0 / 60.0,
                                               cameraOrientation: initialOrientation))

    _ = try #require(transaction.cameraOrientation)
}

@Test func zoomCameraModeProducesDistanceTransactions() throws {
    let mode = ZoomCameraMode()

    let pinchTransaction = mode.makeZoomTransaction(value: 2,
                                                   currentDistance: 3)
    #expect(pinchTransaction.cameraDistance == 1.5)

    let idleTransaction = mode.update(delta: 1.0 / 60.0,
                                      currentDistance: 3)
    let idleTransactionIsNil: Bool
    if case nil = idleTransaction {
        idleTransactionIsNil = true
    } else {
        idleTransactionIsNil = false
    }
    #expect(idleTransactionIsNil)

    mode.addInertia(velocity: 2,
                    currentDistance: 3)
    let inertiaTransaction = try #require(mode.update(delta: 1.0 / 60.0,
                                                      currentDistance: 3))
    #expect(abs((inertiaTransaction.cameraDistance ?? 0) - 2.985) < 0.000001)
}

@Test func trajectoryCameraModeProducesTargetTransaction() throws {
    let mode = TrajectoryCameraMode()
    let camera = TrajectoryCameraMode.CameraInput(
        distance: 3,
        orientation: simd_quatf(angle: 0,
                                axis: SIMD3<Float>(0, 1, 0)),
        target: .zero
    )
    let transaction = mode.makePanTransaction(width: 300,
                                              height: 400,
                                              translation: CGPoint(x: 30, y: 40),
                                              speed: 1,
                                              camera: camera)
    let target = try #require(transaction.cameraTarget)
    let visibleHeight = 2 * 3 * tan(CameraFit.verticalFieldOfView / 2)
    let visibleWidth = visibleHeight * (300.0 / 400.0)
    let expectedTarget = SIMD3<Float>(visibleWidth * 0.1,
                                      visibleHeight * 0.1,
                                      0)

    #expect(simd_length(target - expectedTarget) < 0.000001)
}

@Test func manualCameraModesDoNotCallDirectCameraStateSetters() throws {
    let modesDirectory = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Sources/MetalModule/Camera/Modes")
    let modeFiles = [
        "OrbitCameraMode.swift",
        "ZoomCameraMode.swift",
        "TrajectoryCameraMode.swift"
    ]

    for modeFile in modeFiles {
        let source = try String(contentsOf: modesDirectory.appendingPathComponent(modeFile),
                                encoding: .utf8)
        #expect(!source.contains("cameraState.set("))
        #expect(!source.contains("private unowned var cameraState"))
    }
}

@MainActor
@Test func cameraCoordinatorManualRotationCommitsOneTransaction() {
    let fixture = ManualCameraCoordinatorFixture()
    let initialRevision = fixture.cameraState.revision

    fixture.cameraCoordinator.makeRotation(with: CGPoint(x: 10, y: 5),
                                           velocity: .zero)

    #expect(fixture.cameraState.revision == initialRevision + 1)
}

@MainActor
@Test func cameraCoordinatorManualZoomCommitsOneTransaction() {
    let fixture = ManualCameraCoordinatorFixture()
    let initialRevision = fixture.cameraState.revision

    fixture.cameraCoordinator.makeScale(with: 2,
                                        velocity: 0)

    #expect(fixture.cameraState.revision == initialRevision + 1)
}

@MainActor
@Test func cameraCoordinatorTrajectoryPanCommitsOneTransaction() {
    let fixture = ManualCameraCoordinatorFixture()
    let initialRevision = fixture.cameraState.revision

    fixture.cameraCoordinator.makeTranslation(with: CGPoint(x: 30, y: 40),
                                              viewportSize: CGSize(width: 900, height: 1200))

    #expect(fixture.cameraState.revision == initialRevision + 1)
}

@MainActor
@Test func cameraCoordinatorTrajectoryPanUsesViewportSize() {
    let fixture = ManualCameraCoordinatorFixture()
    let viewportSize = CGSize(width: 900, height: 1200)

    fixture.cameraCoordinator.makeTranslation(with: CGPoint(x: 30, y: 40),
                                              viewportSize: viewportSize)

    let visibleHeight = 2 * fixture.cameraState.cameraDistance * tan(CameraFit.verticalFieldOfView / 2)
    let visibleWidth = visibleHeight * Float(viewportSize.width / viewportSize.height)
    let expectedTarget = SIMD3<Float>(
        Float(30) / Float(viewportSize.width) * visibleWidth,
        Float(40) / Float(viewportSize.height) * visibleHeight,
        0
    )

    #expect(simd_length(fixture.cameraState.cameraTarget - expectedTarget) < 0.000001)
}

@MainActor
@Test func cameraCoordinatorTrajectoryPanSkipsInvalidViewportSize() {
    let fixture = ManualCameraCoordinatorFixture()
    let initialRevision = fixture.cameraState.revision

    fixture.cameraCoordinator.makeTranslation(with: CGPoint(x: 30, y: 40),
                                              viewportSize: .zero)

    #expect(fixture.cameraState.revision == initialRevision)
    #expect(fixture.cameraState.cameraTarget == .zero)
}

@MainActor
private struct ManualCameraCoordinatorFixture {
    let source = ManualCameraSnapshotSource()
    let cameraState: CameraState
    let snapshotProvider: SnapshotProvider
    let cameraCoordinator: CameraCoordinator

    init() {
        cameraState = CameraState()
        snapshotProvider = SnapshotProvider(cameraState: cameraState,
                                            snapshotSource: source)
        cameraCoordinator = CameraCoordinator(cameraState: cameraState,
                                              snapshotProvider: snapshotProvider)
    }
}

@MainActor
private final class ManualCameraSnapshotSource: PreparedRenderSnapshotProviding {
    var latestSnapshot: PreparedRenderSnapshot?

    func requestPreparation(simulationTime: Float) {}
}
