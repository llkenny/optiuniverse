import Foundation

struct SceneRouteRenderState {
    let transfer: TransferOrbitRenderState
    let navigation: NavigationRouteRenderState
}

struct UniverseFrameState {
    let simulationTime: Double
    var presentationTime: Float = 0
    let cameraSnapshot: SnapshotProvider.CameraSnapshot
    let snapshot: UniverseSceneSnapshot?
    let routes: SceneRouteRenderState
}

/// Orbital time is physical seconds since J2000; presentation time is active wall seconds.
struct UniverseSimulationClock {
    private(set) var currentTime: Double = 0
    private(set) var presentationTime: Double = 0

    mutating func advance(by deltaTime: TimeInterval, transfer: TransferSolution? = nil) -> Float {
        guard deltaTime.isFinite, deltaTime > 0 else { return 0 }
        presentationTime += deltaTime
        if let transfer, currentTime < transfer.arrivalEpoch {
            let advanced = currentTime + deltaTime * transfer.flightDuration / TransferSolution.playbackDuration
            let tolerance = max(1e-6, transfer.flightDuration * 1e-12)
            currentTime = transfer.arrivalEpoch - advanced <= tolerance ? transfer.arrivalEpoch : advanced
        } else {
            currentTime += deltaTime * 86_400
        }
        return Float(deltaTime)
    }
}
