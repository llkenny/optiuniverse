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
    private(set) var currentTime: Double
    private(set) var presentationTime: Double = 0
    private(set) var mode: SimulationMode = .live
    private var transferDeparture: Double?
    private let now: () -> Date

    init(now: @escaping () -> Date = Date.init) {
        self.now = now
        currentTime = SimulationTime.tdbSeconds(for: now())
    }

    mutating func synchronizeLive() {
        mode = .live
        transferDeparture = nil
        currentTime = SimulationTime.tdbSeconds(for: now())
    }

    mutating func advance(by deltaTime: TimeInterval, transfer: TransferSolution? = nil) -> Float {
        let deltaTime = deltaTime.isFinite && deltaTime > 0 ? deltaTime : 0
        presentationTime += deltaTime
        if let transfer {
            mode = .transferPreview
            if transferDeparture != transfer.departureEpoch {
                transferDeparture = transfer.departureEpoch
                currentTime = transfer.departureEpoch
            }
            // The completed route remains visible until its camera handoff finishes.
            // Hold its intercept epoch while presentation animations continue.
            guard currentTime < transfer.arrivalEpoch else { return Float(deltaTime) }
            let advanced = currentTime + deltaTime * transfer.flightDuration / TransferSolution.playbackDuration
            let tolerance = max(1e-6, transfer.flightDuration * 1e-12)
            currentTime = transfer.arrivalEpoch - advanced <= tolerance ? transfer.arrivalEpoch : advanced
        } else {
            synchronizeLive()
        }
        return Float(deltaTime)
    }
}
