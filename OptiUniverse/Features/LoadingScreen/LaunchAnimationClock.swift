#if os(iOS)
import QuartzCore
import UIKit

/// Align Canvas invalidations with display refresh instead of accumulating sleep/scheduling drift.
@MainActor
final class LaunchAnimationClock: NSObject {
    private let update: (Double) -> Bool
    private var displayLink: CADisplayLink?
    private var previous: CFTimeInterval?

    init(update: @escaping (Double) -> Bool) {
        self.update = update
    }

    func start() {
        guard displayLink == nil else { return }
        previous = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(frame))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        previous = nil
    }

    /// Readiness may arrive between display callbacks: do not charge that prior time to the flight.
    func synchronize() {
        advance(to: CACurrentMediaTime())
    }

    @objc private func frame(_ link: CADisplayLink) {
        advance(to: link.timestamp)
    }

    private func advance(to time: CFTimeInterval) {
        guard let previous, time >= previous else { return }
        self.previous = time
        if update(time - previous) { stop() }
    }
}
#endif
