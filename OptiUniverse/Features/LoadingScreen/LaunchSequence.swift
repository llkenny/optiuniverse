import Observation
import os

/// Presentation time is advanced only in the foreground, independently of resource preparation.
@MainActor @Observable
final class LaunchSequence {
    enum Phase: Equatable {
        case waiting, lifting, dissolving, completed, cancelled
    }

    nonisolated static let releaseDuration = 0.18
    static let liftDuration = 1.2
    static let fadeDuration = 0.35
    static let reducedFadeDuration = 0.2

    private(set) var elapsed = 0.0
    private(set) var readyAt: Double?
    private(set) var usesReducedMotion = false
    private(set) var isCancelled = false
    private var deliveredCompletion = false
    private var reducedFadeStartOpacity = 1.0
    private var finishingInterval: OSSignpostIntervalState?

    var phase: Phase {
        if isCancelled { return .cancelled }
        guard let readyAt else { return .waiting }
        let time = elapsed - readyAt
        if usesReducedMotion {
            return time >= Self.reducedFadeDuration ? .completed : .dissolving
        }
        if time < Self.releaseDuration { return .waiting }
        if time < Self.releaseDuration + Self.liftDuration { return .lifting }
        return time < Self.releaseDuration + Self.liftDuration + Self.fadeDuration ? .dissolving : .completed
    }

    var liftProgress: Double {
        guard let readyAt, !usesReducedMotion else { return 0 }
        return unit((elapsed - readyAt - Self.releaseDuration) / Self.liftDuration)
    }

    var opacity: Double {
        guard let readyAt else { return 1 }
        if usesReducedMotion {
            return reducedFadeStartOpacity * (1 - unit((elapsed - readyAt) / Self.reducedFadeDuration))
        }
        let fadeAt = readyAt + Self.releaseDuration + Self.liftDuration
        return 1 - unit((elapsed - fadeAt) / Self.fadeDuration)
    }

    func resourcesReady(reduceMotion: Bool) {
        guard readyAt == nil, !isCancelled else { return }
        readyAt = elapsed
        usesReducedMotion = reduceMotion
        finishingInterval = LaunchDiagnostics.signposter.beginInterval(
            "Launch finishing", id: LaunchDiagnostics.signposter.makeSignpostID())
    }

    func reduceMotionEnabled() {
        guard !usesReducedMotion, !isCancelled, phase != .completed else { return }
        reducedFadeStartOpacity = opacity
        usesReducedMotion = true
        if readyAt != nil { readyAt = elapsed }
    }

    /// Returns true exactly once, allowing the host to remove the overlay without a stale callback.
    @discardableResult
    func advance(by interval: Double) -> Bool {
        guard !isCancelled, interval.isFinite, interval >= 0 else { return false }
        elapsed += interval
        guard phase == .completed, !deliveredCompletion else { return false }
        deliveredCompletion = true
        endFinishingInterval()
        return true
    }

    func cancel() {
        isCancelled = true
        endFinishingInterval()
    }

    func reset() {
        endFinishingInterval()
        elapsed = 0
        readyAt = nil
        usesReducedMotion = false
        isCancelled = false
        deliveredCompletion = false
        reducedFadeStartOpacity = 1
    }

    private func unit(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func endFinishingInterval() {
        guard let finishingInterval else { return }
        LaunchDiagnostics.signposter.endInterval("Launch finishing", finishingInterval)
        self.finishingInterval = nil
    }
}
