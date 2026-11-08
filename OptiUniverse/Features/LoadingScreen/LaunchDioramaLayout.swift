import CoreGraphics
import Foundation

/// Ratios and nozzle anchors come from the approved IllustratedLaunchReview-v2 composites.
nonisolated struct LaunchDioramaLayout {
    let size: CGSize

    var diameter: CGFloat { min(size.width, size.height) * 4 / 9 }
    var center: CGPoint { CGPoint(x: size.width / 2, y: size.height / 2) }

    var padRect: CGRect {
        let width = diameter / 0.98
        return CGRect(x: center.x - width / 2, y: center.y - diameter * 0.16,
                      width: width, height: width * 1024 / 1535)
    }

    var engineOnPad: CGPoint {
        CGPoint(x: center.x, y: padRect.minY + padRect.height * 0.515)
    }

    func engine(liftProgress: Double) -> CGPoint {
        // Keep the tip visible in short landscape windows without changing the flight duration.
        let tip = engineOnPad.y - diameter * 0.86 * 0.877
        let distance = min(diameter * 0.7, max(0, tip - min(size.width, size.height) * 0.04))
        return CGPoint(x: engineOnPad.x, y: engineOnPad.y - distance * liftProgress * liftProgress)
    }

    func rocketRect(liftProgress: Double) -> CGRect {
        let height = diameter * 0.86
        let width = height * 713 / 2206
        let nozzle = engine(liftProgress: liftProgress)
        return CGRect(x: nozzle.x - width * 0.502, y: nozzle.y - height * 0.877,
                      width: width, height: height)
    }

    func flameRect(liftProgress: Double, strength: Double, pulse: Double) -> CGRect {
        let height = diameter * (0.195 + 0.26 * min(liftProgress * 3, 1)) * strength * pulse
        let width = height * 1024 / 1536
        let nozzle = engine(liftProgress: liftProgress)
        return CGRect(x: nozzle.x - width / 2, y: nozzle.y - height * 0.12, width: width, height: height)
    }
}

nonisolated struct LaunchDioramaFrame {
    let time: Double
    let flameStrength: Double
    let release: Double
    let liftProgress: Double

    init(elapsed: Double, readyAt: Double?, liftProgress: Double) {
        time = elapsed
        self.liftProgress = liftProgress
        let idleFlame = Self.smooth((elapsed - 0.45) / 0.25)
        let opening = readyAt.map { Self.smooth((elapsed - $0) / LaunchSequence.releaseDuration) } ?? 0
        flameStrength = max(idleFlame, opening)
        release = opening
    }

    private static func smooth(_ value: Double) -> Double {
        let progress = min(max(value, 0), 1)
        return progress * progress * (3 - 2 * progress)
    }
}
