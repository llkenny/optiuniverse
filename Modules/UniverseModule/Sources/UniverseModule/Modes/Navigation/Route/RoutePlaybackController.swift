import Foundation

protocol RoutePlayback {
    var progress: Float { get }
    var elapsedTime: TimeInterval { get }
    var isCompleted: Bool { get }
    func start(duration: TimeInterval)
    func cancel()
    func advance(by delta: TimeInterval)
    func update()
}

extension RoutePlayback {
    func advance(by delta: TimeInterval) {}
}

/// Active frame time drives production playback; an optional injected clock supports deterministic tests.
final class RoutePlaybackController: RoutePlayback {
    private let clock: (() -> TimeInterval)?
    private var duration: TimeInterval = 1
    private var startTime: TimeInterval?
    private var accumulatedTime: TimeInterval = 0
    private var running = false
    private(set) var isCompleted = false

    init(clock: (() -> TimeInterval)? = nil) { self.clock = clock }

    var elapsedTime: TimeInterval {
        guard running || isCompleted else { return 0 }
        let elapsed = clock.flatMap { source in startTime.map { source() - $0 } } ?? accumulatedTime
        return min(duration, max(0, elapsed))
    }

    var progress: Float { Float(elapsedTime / duration) }

    func start(duration: TimeInterval) {
        self.duration = max(duration, .leastNonzeroMagnitude)
        startTime = clock?()
        accumulatedTime = 0
        running = true
        isCompleted = false
    }

    func cancel() {
        running = false
        isCompleted = false
        startTime = nil
        accumulatedTime = 0
    }

    func advance(by delta: TimeInterval) {
        guard running, delta.isFinite, delta > 0 else { return }
        accumulatedTime = min(duration, accumulatedTime + delta)
    }

    func update() {
        guard running, progress >= 1 else { return }
        isCompleted = true
        running = false
    }
}
