import Foundation
import simd

public enum TransferFailure: String, Error, Sendable {
    case invalidGeometry = "A transfer is unavailable for this geometry."
    case didNotConverge = "The transfer calculation did not converge."
    case intersectsSun = "This transfer would intersect the Sun."
}

/// Zero-revolution branch of Izzo (2015), doi:10.1007/s10569-014-9587-y.
/// Uses Izzo's dimensionless time equation with a bounded bracketed inversion.
/// Inputs and outputs are ecliptic km, seconds and km/s. No rendering scale enters the solver.
enum LambertSolver {
    static func solve(from start: SIMD3<Double>, to end: SIMD3<Double>,
                      duration: Double, mu: Double) throws -> (departure: SIMD3<Double>, arrival: SIMD3<Double>) {
        let radius1 = simd_length(start)
        let radius2 = simd_length(end)
        let chord = simd_length(end - start)
        guard duration.isFinite, duration > 0, mu.isFinite, mu > 0,
              radius1.isFinite, radius2.isFinite, radius1 > 0, radius2 > 0, chord > 0 else {
            throw TransferFailure.invalidGeometry
        }
        let radial1 = start / radius1
        let radial2 = end / radius2
        let cross = simd_cross(radial1, radial2)
        guard simd_length(cross) > 1e-12 else { throw TransferFailure.invalidGeometry }
        var normal = simd_normalize(cross)
        let semiperimeter = (radius1 + radius2 + chord) / 2
        var lambda = sqrt(max(0, 1 - chord / semiperimeter))
        // Prograde with respect to the ecliptic north pole, including long-way transfers.
        if normal.z < 0 {
            normal = -normal
            lambda = -lambda
        }
        let target = sqrt(2 * mu / pow(semiperimeter, 3)) * duration
        var lower = -1 + 1e-12
        var upper = 1.0
        for _ in 0..<64 where timeOfFlight(xValue: upper, lambda: lambda) > target { upper *= 2 }
        guard timeOfFlight(xValue: lower, lambda: lambda) >= target,
              timeOfFlight(xValue: upper, lambda: lambda) <= target else {
            throw TransferFailure.didNotConverge
        }
        var xValue = 0.0
        for _ in 0..<100 {
            xValue = (lower + upper) / 2
            if timeOfFlight(xValue: xValue, lambda: lambda) > target { lower = xValue } else { upper = xValue }
        }
        guard abs(timeOfFlight(xValue: xValue, lambda: lambda) - target) <= max(1e-11, target * 1e-10) else {
            throw TransferFailure.didNotConverge
        }
        let yValue = sqrt(1 - lambda * lambda * (1 - xValue * xValue))
        let gamma = sqrt(mu * semiperimeter / 2)
        let rho = (radius1 - radius2) / chord
        let sigma = sqrt(max(0, 1 - rho * rho))
        let sum = lambda * yValue + xValue
        let difference = lambda * yValue - xValue
        let radialVelocity1 = gamma * (difference - rho * sum) / radius1
        let radialVelocity2 = -gamma * (difference + rho * sum) / radius2
        let transverse = gamma * sigma * (yValue + lambda * xValue)
        return (radial1 * radialVelocity1 + simd_cross(normal, radial1) * (transverse / radius1),
                radial2 * radialVelocity2 + simd_cross(normal, radial2) * (transverse / radius2))
    }

    private static func timeOfFlight(xValue: Double, lambda: Double) -> Double {
        let yValue = sqrt(1 - lambda * lambda * (1 - xValue * xValue))
        if abs(xValue - 1) < 0.05 {
            // Battin series avoids cancellation at the parabolic limit xValue = 1.
            let eta = yValue - lambda * xValue
            let argument = (1 - lambda - xValue * eta) / 2
            var term = 1.0
            var hypergeometric = 1.0
            for index in 0..<100 {
                term *= (Double(index) + 3) / (Double(index) + 2.5) * argument
                hypergeometric += term
                if abs(term) < 1e-15 { break }
            }
            return (pow(eta, 3) * (4 / 3.0) * hypergeometric + 4 * lambda * eta) / 2
        }
        let oneMinusXSquared = 1 - xValue * xValue
        let psi: Double
        if xValue < 1 {
            psi = acos(min(1, max(-1, xValue * yValue + lambda * oneMinusXSquared)))
        } else {
            psi = asinh((yValue - xValue * lambda) * sqrt(-oneMinusXSquared))
        }
        return (psi / sqrt(abs(oneMinusXSquared)) - xValue + lambda * yValue) / oneMinusXSquared
    }
}
