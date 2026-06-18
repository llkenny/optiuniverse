import Foundation

struct SceneRouteRenderState {
    let transfer: TransferOrbitRenderState
    let navigation: NavigationRouteRenderState
}

struct UniverseFrameState {
    let simulationTime: Float
    let cameraSnapshot: SnapshotProvider.CameraSnapshot
    let snapshot: PreparedRenderSnapshot?
    let routes: SceneRouteRenderState
}

struct UniverseSimulationClock {
    private(set) var currentTime: Float = 0

    mutating func advance(by deltaTime: TimeInterval) -> Float {
        guard deltaTime.isFinite, deltaTime > 0 else { return 0 }

        let delta = Float(deltaTime)
        currentTime += delta
        return delta
    }
}
