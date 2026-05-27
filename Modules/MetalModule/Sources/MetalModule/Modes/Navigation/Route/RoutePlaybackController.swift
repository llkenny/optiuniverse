//
//  RoutePlaybackController.swift
//  MetalModule
//
//  Created by Codex on 11.05.2026.
//

import Foundation
import QuartzCore

/// Time source abstraction for route playback.
///
/// This protocol is necessary to keep route progress calculation independent from wall-clock APIs.
/// `NavigationRouteCoordinator` owns a value conforming to this protocol and uses it as the single
/// source of route elapsed time and completion state.
protocol RoutePlayback {
    var progress: Float { get }
    var elapsedTime: TimeInterval { get }
    var isCompleted: Bool { get }

    func start(duration: TimeInterval)
    func pause()
    func resume()
    func cancel()
    func update()
}

/// Default wall-clock playback engine for navigation routes.
///
/// `RoutePlaybackController` converts elapsed time into clamped route progress while preserving pause,
/// resume, cancel, and completion semantics. It is necessary because route progress must advance
/// consistently across render frames without coupling the route state machine to `CACurrentMediaTime`.
///
/// Ownership:
/// - Owns only playback timing fields for one route session.
/// - Receives its clock as an injected closure, making tests deterministic.
/// - Does not know about planets, route geometry, camera state, or render state.
/// - Is owned through the `RoutePlayback` protocol by `NavigationRouteCoordinator`.
final class RoutePlaybackController: RoutePlayback {
    private let clock: () -> TimeInterval
    private var duration: TimeInterval = 1
    private var startTime: TimeInterval?
    private var pausedTime: TimeInterval?
    private var accumulatedPauseTime: TimeInterval = 0
    private var completed = false
    private var cancelled = false

    init(clock: @escaping () -> TimeInterval = CACurrentMediaTime) {
        self.clock = clock
    }

    var progress: Float {
        guard duration > 0 else { return 1 }
        return Float(min(max(elapsedTime / duration, 0), 1))
    }

    var elapsedTime: TimeInterval {
        guard let startTime else { return 0 }
        let now = pausedTime ?? clock()
        return min(max(now - startTime - accumulatedPauseTime, 0), duration)
    }

    var isCompleted: Bool {
        completed
    }

    func start(duration: TimeInterval) {
        self.duration = max(duration, .leastNonzeroMagnitude)
        startTime = clock()
        pausedTime = nil
        accumulatedPauseTime = 0
        completed = false
        cancelled = false
    }

    func pause() {
        guard startTime != nil,
              pausedTime == nil,
              !completed,
              !cancelled else {
            return
        }

        pausedTime = clock()
    }

    func resume() {
        guard let pausedTime,
              !completed,
              !cancelled else {
            return
        }

        accumulatedPauseTime += clock() - pausedTime
        self.pausedTime = nil
    }

    func cancel() {
        cancelled = true
        completed = false
        startTime = nil
        pausedTime = nil
        accumulatedPauseTime = 0
    }

    func update() {
        guard startTime != nil,
              pausedTime == nil,
              !completed,
              !cancelled,
              progress >= 1 else {
            return
        }

        completed = true
    }
}
