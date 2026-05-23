//
//  CameraCoordinator.swift
//  MetalModule
//
//  Created by max on 22.05.2026.
//

import CoreFoundation
import QuartzCore

/// Owns camera mode priority, ownership, cancellation, and ticking.
/// It decides which mode receives a command or time update, whether a command cancels or suspends another mode, and which transactional camera mutation is committed.
/*
 Camera mode priority becomes explicit.
 Conflicts such as manual control cancelling follow, navigation owning the camera while active,
 or trajectory pan only applying in trajectory mode should be resolved by the camera mode layer or a camera coordinator,
 not by renderer branches.

 The coordinator must stay focused on routing and ownership.
 It should not perform matrix math or directly encode mode-specific camera behavior.
 Mode-specific transformations belong in the modes, and matrix derivation belongs in the snapshot provider.

 The implementation should avoid letting every mode freely mutate state in incompatible ways.
 Modes should emit camera commands or transactional mutations through `CameraCoordinator`
 so ownership and cancellation rules remain visible.
 */
// TODO: Remoe MainActor
@MainActor
final class CameraCoordinator {
    enum Mode {
        case orbit
        case navigation
        case trajectory

        var priority: Int {
            switch self {
            case .orbit: return 100
            case .navigation: return 50
            case .trajectory: return 25
            }
        }
    }

    enum Value {
        case target(SIMD3<Float>)
        case position(SIMD3<Float>)
    }

    protocol CameraModeProtocol: AnyObject {
//        var isActive: Bool { get }
        func update(deltaTime: Float)
//        func command(_ command: CameraCommand)
//        func set(value: Value)

        /// Apply mode based adjustments
        func apply(cameraState: CameraState)
    }

    // MARK: Constants
    private let orbitSpeed: Float = 0.01

    // TODO: Now thinking only on preparing data with CameraState end
    // TODO: Assume not ticrate and timedelta for the first step:
    // all the data instantly passed to CameraState through the current mode
    //
    // Also No Snapshot - it is the next step

    // TODO: Let's start with pan and orbit mode

    private var currentMode: Mode = .orbit
    private let cameraState: CameraState

    // TODO: Remove modes from CameraController and MetalRenderer, Modes must be accessed only from the class
    private let zoomMode: ZoomCameraMode
    private let orbitMode: OrbitCameraMode
    private let trajectoryMode: TrajectoryCameraMode
    private let navigationMode: NavigationCameraMode

    // TODO: Add Metal display link as tic rate
    private var displayLink: CADisplayLink?

    // TODO: Add inertia post effect
    // TODO: Remove renderer after SnapshotProvider implementation
    var renderer: MetalRenderer?

    init(cameraState: CameraState,
         displayLink: CADisplayLink? = nil) {
        self.cameraState = cameraState
        self.displayLink = displayLink
        zoomMode = .init(cameraState: cameraState)
        orbitMode = .init(cameraState: cameraState)
        trajectoryMode = .init(cameraState: cameraState)
        navigationMode = .init(cameraState: cameraState)

        startLoop()
    }

    // Updates can came from UI or current mode continious work
    // UI actually doesn't know which mode is it and can't change the mode
    // The mode is changing by special events: e.g. buttons
    // Active mode can yield additions by time

    // So why is it necessary to maintain priority?

    func set(mode: Mode) {
        guard currentMode != mode else { return }
        currentMode = mode
    }

    // TODO: How to work for the late evening?
    // Buy something at 7/11 for the second breath?
    // Take mid-day break? PrimeVideo at evenings?

//    func update(value: Value) {
//    }

    func makeTranslation(with value: CGPoint) {
        trajectoryMode.apply(translation: value)
    }

    func makeRotation(with value: CGPoint, velocity: CGPoint) {
//        switch currentMode {
//        case .orbit, .navigation:
//            orbitMode.apply(horizontal: Float(value.x) * orbitSpeed,
//                            vertical: -Float(value.y) * orbitSpeed)
//        case .trajectory:
//        }
        orbitMode.apply(horizontal: Float(value.x) * orbitSpeed,
                        vertical: -Float(value.y) * orbitSpeed)
        orbitMode.addInertia(velocity: velocity)
    }

    func makeScale(with value: Float, velocity: CGFloat) {
        zoomMode.apply(value: value)
        zoomMode.addInertia(velocity: velocity)
    }

    private func update(delta: Float) {
        zoomMode.update(delta: delta)
        orbitMode.update(delta: delta)
        
        // TODO: The renderer must picks himself actual camera values from CameraState with SnapshotProvider
        renderer?.updateCamera()
    }

    // MARK: Update loop

    private func stopLoop() {
        // TODO: Add stop
        displayLink?.invalidate()
    }

    private func startLoop() {
        displayLink = CADisplayLink(target: self, selector: #selector(step(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    @objc private func step(_ link: CADisplayLink) {
        let delta = Float(link.duration)
        update(delta: delta)
    }
}
