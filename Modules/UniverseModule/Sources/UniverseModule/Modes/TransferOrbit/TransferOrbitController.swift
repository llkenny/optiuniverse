//
//  TransferOrbitController.swift
//  UniverseModule
//
//  Created by Codex on 28.05.2026.
//

import CoreGraphics
import simd

@MainActor
final class TransferOrbitController {
    private unowned let snapshotProvider: SnapshotProvider
    private unowned let cameraCoordinator: any TransferPreviewCameraCoordinating
    private let planets: [Planet]
    private let viewportSize: () -> CGSize

    var followPlanet: ((String) -> Void)?

    private var pendingDestinationName: String?
    private var activeDestinationName: String?
    private var activeTransferOrbit: HohmannTransferOrbit?
    private var cameraTransition: CameraTransition?

    init(snapshotProvider: SnapshotProvider,
         cameraCoordinator: any TransferPreviewCameraCoordinating,
         planets: [Planet],
         viewportSize: @escaping () -> CGSize) {
        self.snapshotProvider = snapshotProvider
        self.cameraCoordinator = cameraCoordinator
        self.planets = planets
        self.viewportSize = viewportSize
    }

    var isTransferPreviewActive: Bool {
        activeTransferOrbit != nil
    }

    var cameraSnapshotDependency: CameraTransferSnapshotDependency? {
        guard activeDestinationName != nil ||
              pendingDestinationName != nil ||
              cameraTransition != nil else {
            return nil
        }

        return CameraTransferSnapshotDependency(
            destinationName: activeDestinationName ?? pendingDestinationName,
            hasActiveTransition: cameraTransition != nil
        )
    }

    var renderState: TransferOrbitRenderState {
        TransferOrbitRenderState(transferOrbit: activeTransferOrbit)
    }

    func showTransferOrbit(to destinationName: String) {
        guard let snapshot = snapshotProvider.latestSnapshot,
              applyTransferOrbit(destinationName: destinationName,
                                 snapshot: snapshot) else {
            pendingDestinationName = destinationName
            cameraTransition = nil
            return
        }

        pendingDestinationName = nil
    }

    func clearTransferOrbit() {
        pendingDestinationName = nil
        activeDestinationName = nil
        activeTransferOrbit = nil
        cameraTransition = nil
    }

    func cancelTransferOrbit() {
        let destinationName = activeDestinationName ?? pendingDestinationName

        clearTransferOrbit()

        guard let destinationName else { return }
        followPlanet?(destinationName)
    }

    func beginManualCameraControl() {
        cameraTransition = nil
    }

    func update(snapshot: PreparedRenderSnapshot?,
                delta: Float) {
        guard let snapshot else { return }

        if let destinationName = pendingDestinationName,
           applyTransferOrbit(destinationName: destinationName,
                              snapshot: snapshot) {
            pendingDestinationName = nil
        } else {
            updateActiveTransferOrbit(snapshot: snapshot)
        }

        updateCameraTransition(snapshot: snapshot,
                               delta: delta)
    }

    func projectionParameters(snapshot: PreparedRenderSnapshot?,
                              baseProjection: CameraProjectionParameters) -> CameraProjectionParameters {
        guard let snapshot,
              let activeTransferOrbit,
              let transferRadius = transferProjectionRadius(transferOrbit: activeTransferOrbit,
                                                            snapshot: snapshot) else {
            return baseProjection
        }

        return baseProjection.withClippingPlanes(
            farPlane: max(baseProjection.farPlane,
                          CameraFit.defaultFarPlane,
                          cameraCoordinator.cameraDistance + transferRadius * 1.15)
        )
    }

    private func applyTransferOrbit(destinationName: String,
                                    snapshot: PreparedRenderSnapshot) -> Bool {
        guard let transferOrbit = makeTransferOrbit(destinationName: destinationName,
                                                    snapshot: snapshot) else {
            clearTransferOrbit()
            followPlanet?(destinationName)
            return true
        }

        activeDestinationName = destinationName
        activeTransferOrbit = transferOrbit
        startTransferOverviewAnimation(transferOrbit: transferOrbit,
                                       snapshot: snapshot)
        return true
    }

    private func updateActiveTransferOrbit(snapshot: PreparedRenderSnapshot) {
        guard let activeDestinationName else { return }

        guard let transferOrbit = makeTransferOrbit(destinationName: activeDestinationName,
                                                    snapshot: snapshot) else {
            clearTransferOrbit()
            return
        }

        activeTransferOrbit = transferOrbit
    }

    private func makeTransferOrbit(destinationName: String,
                                   snapshot: PreparedRenderSnapshot) -> HohmannTransferOrbit? {
        guard let sunPosition = snapshot.worldPosition(ofPlanetNamed: "Sun"),
              let earthPosition = snapshot.worldPosition(ofPlanetNamed: "Earth") else {
            return nil
        }

        return HohmannTransferOrbit.make(destinationName: destinationName,
                                         planets: planets,
                                         earthSunDirection: earthPosition - sunPosition,
                                         sunPosition: sunPosition)
    }

    private func startTransferOverviewAnimation(transferOrbit: HohmannTransferOrbit,
                                                snapshot: PreparedRenderSnapshot) {
        guard let framing = earthCenteredTransferFraming(transferOrbit: transferOrbit,
                                                         snapshot: snapshot) else {
            return
        }

        cameraTransition = CameraTransition(
            start: cameraCoordinator.currentCameraTransitionFrame,
            destination: .fixed(target: framing.center,
                                distance: distanceToFitPlanet(radius: framing.radius) * 1.08),
            duration: cameraCoordinator.cameraFollowTransitionDuration
        )
    }

    private func updateCameraTransition(snapshot: PreparedRenderSnapshot,
                                        delta: Float) {
        guard var transition = cameraTransition else { return }
        guard let frame = transition.advance(delta: delta, resolveDestination: { [weak self] destination in
            guard let self else { return nil }
            return self.resolveCameraTransitionDestination(destination,
                                                           snapshot: snapshot)
        }) else {
            return
        }

        cameraTransition = transition.isComplete ? nil : transition
        cameraCoordinator.commitTransferPreviewTransition(frame: frame)
    }

    private func resolveCameraTransitionDestination(_ destination: CameraTransition.Destination,
                                                    snapshot: PreparedRenderSnapshot)
    -> CameraTransition.Frame? {
        switch destination {
        case .planet(let name):
            guard let position = snapshot.worldPosition(ofPlanetNamed: name),
                  let framingRadius = snapshot.framingRadius(ofPlanetNamed: name) else {
                return nil
            }
            return CameraTransition.Frame(target: position,
                                          distance: distanceToFitPlanet(radius: framingRadius))
        case .fixed(let target, let distance):
            return CameraTransition.Frame(target: target,
                                          distance: distance)
        }
    }

    private func earthCenteredTransferFraming(transferOrbit: HohmannTransferOrbit,
                                              snapshot: PreparedRenderSnapshot)
    -> (center: SIMD3<Float>, radius: Float)? {
        guard let earthPosition = snapshot.worldPosition(ofPlanetNamed: "Earth") else {
            return nil
        }

        var framingRadius: Float = 0
        func include(center: SIMD3<Float>, radius: Float) {
            framingRadius = max(framingRadius,
                                simd_distance(earthPosition, center) + max(radius, 0))
        }

        for point in transferOrbit.points {
            include(center: point, radius: 0)
        }

        include(center: transferOrbit.sunPosition,
                radius: max(transferOrbit.earthOrbitRadius,
                            transferOrbit.destinationOrbitRadius))

        for planetName in ["Sun", "Earth", transferOrbit.destinationName] {
            guard let planetPosition = snapshot.worldPosition(ofPlanetNamed: planetName) else {
                continue
            }
            include(center: planetPosition,
                    radius: snapshot.framingRadius(ofPlanetNamed: planetName) ?? 0)
        }

        guard framingRadius.isFinite else { return nil }
        return (earthPosition, max(framingRadius, 0.001))
    }

    private func transferProjectionRadius(transferOrbit: HohmannTransferOrbit,
                                          snapshot: PreparedRenderSnapshot) -> Float? {
        var radius: Float = 0

        func include(center: SIMD3<Float>, radius includedRadius: Float) {
            radius = max(radius,
                         simd_distance(cameraCoordinator.cameraTarget, center) + max(includedRadius, 0))
        }

        for point in transferOrbit.points {
            include(center: point, radius: 0)
        }

        include(center: transferOrbit.sunPosition,
                radius: max(transferOrbit.earthOrbitRadius,
                            transferOrbit.destinationOrbitRadius))

        for planetName in ["Sun", "Earth", transferOrbit.destinationName] {
            guard let planetPosition = snapshot.worldPosition(ofPlanetNamed: planetName) else {
                continue
            }

            include(center: planetPosition,
                    radius: snapshot.framingRadius(ofPlanetNamed: planetName) ?? 0)
        }

        guard radius.isFinite else { return nil }
        return max(radius, 0.001)
    }

    private func distanceToFitPlanet(radius: Float) -> Float {
        CameraFit.distanceToFit(radius: radius,
                                currentDistance: cameraCoordinator.cameraDistance,
                                viewportSize: viewportSize())
    }
}
