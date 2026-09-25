import Foundation
import simd

/// Universal-variable propagation supports elliptic, parabolic and hyperbolic Lambert arcs.
struct TwoBodyTrajectory: Equatable, Sendable {
    static let solarMu = 132_712_440_041.27942
    let initialPosition: SIMD3<Double>
    let initialVelocity: SIMD3<Double>
    let mu: Double

    func state(after seconds: Double) throws -> OrbitalState {
        guard seconds.isFinite, seconds >= 0 else { throw TransferFailure.invalidGeometry }
        if seconds == 0 { return OrbitalState(position: initialPosition, velocity: initialVelocity) }
        let radius = simd_length(initialPosition)
        let rootMu = sqrt(mu)
        let radialProduct = simd_dot(initialPosition, initialVelocity) / rootMu
        let alpha = 2 / radius - simd_length_squared(initialVelocity) / mu
        func timeEquation(_ anomaly: Double) -> Double {
            let (cValue, sValue) = Self.stumpff(alpha * anomaly * anomaly)
            return radialProduct * anomaly * anomaly * cValue +
                (1 - alpha * radius) * pow(anomaly, 3) * sValue + radius * anomaly
        }
        let target = rootMu * seconds
        var lower = 0.0
        var upper = max(1, rootMu * seconds / radius)
        for _ in 0..<64 where timeEquation(upper) < target { upper *= 2 }
        guard timeEquation(upper) >= target else { throw TransferFailure.didNotConverge }
        for _ in 0..<100 {
            let middle = (lower + upper) / 2
            if timeEquation(middle) < target { lower = middle } else { upper = middle }
        }
        let anomaly = (lower + upper) / 2
        let (cValue, sValue) = Self.stumpff(alpha * anomaly * anomaly)
        let fValue = 1 - anomaly * anomaly / radius * cValue
        let gValue = seconds - pow(anomaly, 3) / rootMu * sValue
        let position = fValue * initialPosition + gValue * initialVelocity
        let newRadius = simd_length(position)
        let fRate = rootMu / (radius * newRadius) * (alpha * pow(anomaly, 3) * sValue - anomaly)
        let gRate = 1 - anomaly * anomaly / newRadius * cValue
        let velocity = fRate * initialPosition + gRate * initialVelocity
        guard newRadius.isFinite, newRadius > 0, simd_length(velocity).isFinite,
              abs(timeEquation(anomaly) - target) <= max(1e-5, target * 1e-10) else {
            throw TransferFailure.didNotConverge
        }
        return OrbitalState(position: position, velocity: velocity)
    }

    /// Minimum radius on a zero-revolution prograde arc, including a periapsis between samples.
    func minimumRadius(endingAt end: SIMD3<Double>) -> Double {
        let momentum = simd_cross(initialPosition, initialVelocity)
        let normal = simd_normalize(momentum)
        let eccentricityVector = simd_cross(initialVelocity, momentum) / mu - simd_normalize(initialPosition)
        let eccentricity = simd_length(eccentricityVector)
        let periapsis = simd_length_squared(momentum) / (mu * (1 + eccentricity))
        if eccentricity < 1e-12 { return periapsis }
        func forwardAngle(to vector: SIMD3<Double>) -> Double {
            let angle = atan2(simd_dot(normal, simd_cross(initialPosition, vector)),
                              simd_dot(initialPosition, vector))
            return angle < 0 ? angle + 2 * .pi : angle
        }
        if forwardAngle(to: eccentricityVector) <= forwardAngle(to: end) { return periapsis }
        return min(simd_length(initialPosition), simd_length(end))
    }

    private static func stumpff(_ value: Double) -> (Double, Double) {
        if abs(value) < 1e-4 {
            let squared = value * value
            return (0.5 - value / 24 + squared / 720 - squared * value / 40_320,
                    1 / 6.0 - value / 120 + squared / 5_040 - squared * value / 362_880)
        }
        if value > 0 {
            let root = sqrt(value)
            return ((1 - cos(root)) / value, (root - sin(root)) / pow(root, 3))
        }
        let root = sqrt(-value)
        return ((cosh(root) - 1) / -value, (sinh(root) - root) / pow(root, 3))
    }
}
