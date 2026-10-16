import Foundation
import simd
import Testing
@testable import UniverseModule

@MainActor
struct NavigationControllerFixture {
    func updateTransfer(progress: Double) {
        guard let transfer = controller.routeRenderState.route?.transfer else {
            Issue.record("Missing transfer")
            return
        }
        let snapshot = orbitalTestSnapshot(time: transfer.departureEpoch + progress * transfer.flightDuration)
        controller.update(snapshot: snapshot, delta: 0.1)
    }

    let snapshot: UniverseSceneSnapshot
    let source: FakeNavigationSnapshotSource
    let provider: SnapshotProvider
    let cameraState: CameraState
    let controller: NavigationController

    init(snapshot: UniverseSceneSnapshot? = .navigationControllerTestSnapshot,
         routePlayback: RoutePlayback = RoutePlaybackController()) {
        self.snapshot = snapshot ?? .navigationControllerTestSnapshot
        source = FakeNavigationSnapshotSource(latestSnapshot: snapshot)
        cameraState = CameraState()
        provider = SnapshotProvider(cameraState: cameraState,
                                    snapshotSource: source)
        controller = NavigationController(snapshotProvider: provider,
                                          planets: testPlanets,
                                          routePlayback: routePlayback)
    }
}

final class CompletingRoutePlayback: RoutePlayback {
    private(set) var progress: Float = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var isCompleted = false
    private var duration: TimeInterval = 1

    func start(duration: TimeInterval) {
        self.duration = duration
        progress = 0
        elapsedTime = 0
        isCompleted = false
    }

    func cancel() {
        progress = 0
        elapsedTime = 0
        isCompleted = false
    }

    func update() {
        progress = 1
        elapsedTime = duration
        isCompleted = true
    }
}

final class AdvancingRoutePlayback: RoutePlayback {
    private let progressAfterUpdate: Float
    private(set) var progress: Float = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var isCompleted = false

    init(progressAfterUpdate: Float) {
        self.progressAfterUpdate = progressAfterUpdate
    }

    func start(duration: TimeInterval) {
        progress = 0
        elapsedTime = 0
        isCompleted = false
    }

    func cancel() {
        progress = 0
        elapsedTime = 0
        isCompleted = false
    }

    func update() {
        progress = progressAfterUpdate
        elapsedTime = TimeInterval(progressAfterUpdate)
    }
}

@MainActor
final class FakeNavigationSnapshotSource: UniverseSceneSnapshotProviding {
    var latestSnapshot: UniverseSceneSnapshot?

    init(latestSnapshot: UniverseSceneSnapshot?) {
        self.latestSnapshot = latestSnapshot
    }

    func requestPreparation(simulationTime: Double) {}
}

extension UniverseSceneSnapshot {
    static var navigationControllerTestSnapshot: UniverseSceneSnapshot {
        UniverseSceneSnapshot(frameID: 1,
                               simulationTime: 0,
                               planets: [
                                navigationControllerTestPacket(name: "Sun",
                                           worldPosition: SIMD3<Float>(0, 0, 0),
                                           framingRadius: 0.2),
                                navigationControllerTestPacket(name: "Earth",
                                           worldPosition: SIMD3<Float>(1, 0, 0),
                                           framingRadius: 0.05),
                                navigationControllerTestPacket(name: "Mars",
                                           worldPosition: SIMD3<Float>(1.52, 0, 0),
                                           framingRadius: 0.05)
                               ])
    }

    static var movedDestinationSnapshot: UniverseSceneSnapshot {
        UniverseSceneSnapshot(frameID: 2,
                               simulationTime: 1,
                               planets: [
                                navigationControllerTestPacket(name: "Sun",
                                           worldPosition: SIMD3<Float>(0, 0, 0),
                                           framingRadius: 0.2),
                                navigationControllerTestPacket(name: "Earth",
                                           worldPosition: SIMD3<Float>(1, 0, 0),
                                           framingRadius: 0.05),
                                navigationControllerTestPacket(name: "Mars",
                                           worldPosition: SIMD3<Float>(0, 0, -1.52),
                                           framingRadius: 0.05)
                               ])
    }

    static var cislunarNavigationControllerTestSnapshot: UniverseSceneSnapshot {
        UniverseSceneSnapshot(frameID: 1,
                               simulationTime: 0,
                               planets: [
                                navigationControllerTestPacket(name: "Sun",
                                           worldPosition: SIMD3<Float>(0, 0, 0),
                                           framingRadius: 0.2),
                                navigationControllerTestPacket(name: "Earth",
                                           worldPosition: SIMD3<Float>(1, 0, 0),
                                           framingRadius: 0.05),
                                navigationControllerTestPacket(name: "Moon",
                                           worldPosition: SIMD3<Float>(1.2, 0, 0),
                                           framingRadius: 0.02)
                               ])
    }

    static func navigationControllerTestPacket(name: String,
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
