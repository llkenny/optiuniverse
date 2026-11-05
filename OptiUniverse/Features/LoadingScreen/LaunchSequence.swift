import Observation

/// Presentation time is advanced only in the foreground, independently of resource preparation.
@MainActor @Observable
final class LaunchSequence {
    enum Phase: Equatable {
        case waiting, lifting, dissolving, completed, cancelled
    }

    static let ignitionDuration = 0.18
    static let liftDuration = 1.2
    static let fadeDuration = 0.35
    static let reducedFadeDuration = 0.2

    private(set) var elapsed = 0.0
    private(set) var readyAt: Double?
    private(set) var usesReducedMotion = false
    private(set) var isCancelled = false
    private var deliveredCompletion = false

    var phase: Phase {
        if isCancelled { return .cancelled }
        guard let readyAt else { return .waiting }
        let time = elapsed - readyAt
        if usesReducedMotion {
            return time >= Self.reducedFadeDuration ? .completed : .dissolving
        }
        if time < Self.ignitionDuration { return .waiting }
        if time < Self.ignitionDuration + Self.liftDuration { return .lifting }
        return time < Self.ignitionDuration + Self.liftDuration + Self.fadeDuration ? .dissolving : .completed
    }

    var liftProgress: Double {
        guard let readyAt, !usesReducedMotion else { return 0 }
        return unit((elapsed - readyAt - Self.ignitionDuration) / Self.liftDuration)
    }

    var opacity: Double {
        guard let readyAt else { return 1 }
        if usesReducedMotion {
            return 1 - unit((elapsed - readyAt) / Self.reducedFadeDuration)
        }
        let fadeAt = readyAt + Self.ignitionDuration + Self.liftDuration
        return 1 - unit((elapsed - fadeAt) / Self.fadeDuration)
    }

    var ignition: Double {
        guard !usesReducedMotion else { return 0 }
        let idle = unit(elapsed / 0.8) * 0.28
        guard let readyAt else { return idle }
        return idle + (1 - idle) * unit((elapsed - readyAt) / Self.ignitionDuration)
    }

    func resourcesReady(reduceMotion: Bool) {
        guard readyAt == nil, !isCancelled else { return }
        readyAt = elapsed
        usesReducedMotion = reduceMotion
    }

    func reduceMotionEnabled() {
        guard !usesReducedMotion, !isCancelled, phase != .completed else { return }
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
        return true
    }

    func cancel() {
        isCancelled = true
    }

    func reset() {
        elapsed = 0
        readyAt = nil
        usesReducedMotion = false
        isCancelled = false
        deliveredCompletion = false
    }

    private func unit(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
