import CoreGraphics
import simd

@MainActor
final class TransferOrbitController {
    private unowned let snapshotProvider: SnapshotProvider
    private unowned let cameraCoordinator: any TransferPreviewCameraCoordinating
    private let planets: [Planet]
    private let viewportSize: () -> CGSize
    var followPlanet: ((String) -> Void)?
    var transferPreviewDidBegin: (() -> Void)?
    var snapshotDidChange: ((TransferPreviewSnapshot) -> Void)?
    private(set) var previewSnapshot = TransferPreviewSnapshot.inactive {
        didSet { if oldValue != previewSnapshot { snapshotDidChange?(previewSnapshot) } }
    }
    private var activeDestinationName: String?
    private var activeTransferOrbit: TransferSolution?
    private var cameraTransition: CameraTransition?
    private var earthPoints: [SIMD3<Float>] = []
    private var destinationPoints: [SIMD3<Float>] = []
    private var calculation: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var lastRequestedEpoch: Double?
    private var refreshElapsed: Float = 1
    private var needsFraming = false

    init(snapshotProvider: SnapshotProvider,
         cameraCoordinator: any TransferPreviewCameraCoordinating,
         planets: [Planet], viewportSize: @escaping () -> CGSize) {
        self.snapshotProvider = snapshotProvider
        self.cameraCoordinator = cameraCoordinator
        self.planets = planets
        self.viewportSize = viewportSize
    }

    var isTransferPreviewActive: Bool { activeDestinationName != nil }

    var cameraSnapshotDependency: CameraTransferSnapshotDependency? {
        guard let activeDestinationName else { return nil }
        return CameraTransferSnapshotDependency(destinationName: activeDestinationName,
                                                 hasActiveTransition: cameraTransition != nil,
                                                 maximumCameraDistance: max(CameraState.defaultMaximumDistance,
                                                   overviewDistance * 1.2))
    }

    var renderState: TransferOrbitRenderState {
        TransferOrbitRenderState(transferOrbit: activeTransferOrbit,
                                 earthOrbitPoints: earthPoints, destinationOrbitPoints: destinationPoints)
    }

    func showTransferOrbit(to destinationName: String) {
        generation += 1
        activeDestinationName = destinationName
        activeTransferOrbit = nil
        lastRequestedEpoch = nil
        refreshElapsed = 1
        cameraTransition = nil
        needsFraming = true
        earthPoints = planets.first { $0.name == "Earth" }?.orbit?.orbitPoints() ?? []
        destinationPoints = planets.first { $0.name == destinationName }?.orbit?.orbitPoints() ?? []
        previewSnapshot = TransferPreviewSnapshot(status: .preparing, destinationName: destinationName)
        transferPreviewDidBegin?()
        if let snapshot = snapshotProvider.latestSnapshot { requestCalculation(snapshot: snapshot) }
    }

    func clearTransferOrbit() {
        generation += 1
        activeDestinationName = nil
        activeTransferOrbit = nil
        cameraTransition = nil
        earthPoints = []
        destinationPoints = []
        previewSnapshot = .inactive
        // Let an in-flight computation finish; the generation check discards it.
        // Keeping the slot occupied prevents concurrent workers after rapid destination changes.
    }

    func cancelTransferOrbit() {
        let destination = activeDestinationName
        clearTransferOrbit()
        if let destination { followPlanet?(destination) }
    }

    func beginManualCameraControl() { cameraTransition = nil; needsFraming = false }

    func update(snapshot: UniverseSceneSnapshot?, delta: Float) {
        guard let snapshot, isTransferPreviewActive else { return }
        refreshElapsed += delta
        if refreshElapsed >= 0.25 { requestCalculation(snapshot: snapshot) }
        if var transition = cameraTransition,
           let frame = transition.advance(delta: delta, resolveDestination: { destination in
               if case let .fixed(target, distance, orientation) = destination {
                   return CameraTransition.Frame(target: target, distance: distance, orientation: orientation)
               }
               return nil
           }) {
            cameraTransition = transition.isComplete ? nil : transition
            cameraCoordinator.commitTransferPreviewTransition(frame: frame)
        }
    }

    private func requestCalculation(snapshot: UniverseSceneSnapshot) {
        guard calculation == nil, let destination = activeDestinationName,
              lastRequestedEpoch != snapshot.simulationTime else { return }
        if case .failed = previewSnapshot.status { return } // Retry is explicit after failure.
        let requestGeneration = generation
        let epoch = snapshot.simulationTime
        lastRequestedEpoch = epoch
        refreshElapsed = 0
        let planets = planets
        let sun = snapshot.worldPosition(ofPlanetNamed: "Sun") ?? .zero
        calculation = Task { [weak self] in
            let result = await Task.detached(priority: .userInitiated) {
                Result { try TransferSolution.make(destinationName: destination, planets: planets,
                                                     departureEpoch: epoch, sunPosition: sun) }
            }.value
            guard let self else { return }
            calculation = nil
            guard generation == requestGeneration, activeDestinationName == destination else { return }
            switch result {
            case .success(let solution):
                activeTransferOrbit = solution
                earthPoints = solution.earthOrbitPoints
                destinationPoints = solution.destinationOrbitPoints
                previewSnapshot = TransferPreviewSnapshot(status: .ready, destinationName: destination,
                                                            physicalFlightDuration: solution.flightDuration)
            case .failure(let error):
                activeTransferOrbit = nil
                previewSnapshot = TransferPreviewSnapshot(status: .failed((error as? TransferFailure) ?? .didNotConverge),
                                                            destinationName: destination)
            }
            if needsFraming { frameOverview(); needsFraming = false }
        }
    }

    private var framingRadius: Float {
        max(activeTransferOrbit?.framingRadius ?? 0,
            (earthPoints + destinationPoints).reduce(0) { max($0, simd_length($1)) }, 1)
    }

    private var overviewDistance: Float {
        CameraFit.distanceToFitWidth(radius: framingRadius,
                                     currentDistance: cameraCoordinator.cameraDistance,
                                     viewportSize: viewportSize())
    }

    private func frameOverview() {
        let distance = overviewDistance
        // Preserve the atomic outer-system handoff: those distances exceed the normal gesture range.
        if distance > CameraState.defaultMaximumDistance {
            cameraTransition = nil
            cameraCoordinator.commitTransferPreviewTransition(frame: CameraTransition.Frame(
                target: activeTransferOrbit?.sunPosition ?? .zero, distance: distance,
                orientation: OverviewCameraFraming.orientation
            ))
            return
        }
        cameraTransition = CameraTransition(
            start: cameraCoordinator.currentCameraTransitionFrame,
            destination: .fixed(target: activeTransferOrbit?.sunPosition ?? .zero,
                                distance: distance, orientation: OverviewCameraFraming.orientation),
            duration: cameraCoordinator.cameraFollowTransitionDuration
        )
    }

    func projectionParameters(snapshot: UniverseSceneSnapshot?,
                              baseProjection: CameraProjectionParameters) -> CameraProjectionParameters {
        guard isTransferPreviewActive else { return baseProjection }
        let radius = framingRadius + simd_length(cameraCoordinator.cameraTarget)
        return baseProjection.withClippingPlanes(farPlane: max(baseProjection.farPlane,
                                                                cameraCoordinator.cameraDistance + 2 * radius))
    }
}
