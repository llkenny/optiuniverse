import Foundation
import simd

/// Fixed J2000 ecliptic elements. Distances are km, periods seconds, angles degrees.
struct OrbitalElements: Codable, Equatable, Sendable {
    static let j2000 = 2_451_545.0
    static let sceneUnitsPerKm = 1e-6
    let semiMajorAxisKm: Double
    let eccentricity: Double
    let inclinationDegrees: Double
    let ascendingNodeDegrees: Double
    let argumentOfPeriapsisDegrees: Double
    let meanAnomalyDegrees: Double
    let epochJulianDay: Double
    let periodSeconds: Double

    var isValid: Bool {
        [semiMajorAxisKm, eccentricity, inclinationDegrees, ascendingNodeDegrees,
         argumentOfPeriapsisDegrees, meanAnomalyDegrees, epochJulianDay, periodSeconds]
            .allSatisfy(\.isFinite) && semiMajorAxisKm > 0 && periodSeconds > 0 &&
            eccentricity >= 0 && eccentricity < 1
    }

    /// Seconds since J2000. Reducing time before multiplying avoids losing phase precision.
    func state(at seconds: Double) -> OrbitalState {
        let elapsed = seconds - (epochJulianDay - Self.j2000) * 86_400
        let meanMotion = 2 * Double.pi / periodSeconds
        let mean = meanAnomalyDegrees * .pi / 180 +
            elapsed.truncatingRemainder(dividingBy: periodSeconds) * meanMotion
        let eccentricAnomaly = Self.solveKepler(mean: mean, eccentricity: eccentricity)
        let cosine = cos(eccentricAnomaly)
        let sine = sin(eccentricAnomaly)
        let minorFactor = sqrt(1 - eccentricity * eccentricity)
        let position = SIMD3(semiMajorAxisKm * (cosine - eccentricity),
                             semiMajorAxisKm * minorFactor * sine, 0)
        let rate = meanMotion / (1 - eccentricity * cosine)
        let velocity = SIMD3(-semiMajorAxisKm * sine * rate,
                             semiMajorAxisKm * minorFactor * cosine * rate, 0)
        return OrbitalState(position: oriented(position), velocity: oriented(velocity))
    }

    func orbitPoints(sampleCount: Int = 256) -> [SIMD3<Float>] {
        guard isValid, sampleCount >= 4 else { return [] }
        return (0...sampleCount).map { index in
            let angle = 2 * Double.pi * Double(index) / Double(sampleCount)
            let point = SIMD3(semiMajorAxisKm * (cos(angle) - eccentricity),
                              semiMajorAxisKm * sqrt(1 - eccentricity * eccentricity) * sin(angle), 0)
            return OrbitalState.scenePosition(oriented(point))
        }
    }

    /// Rotation from perifocal coordinates to the J2000 ecliptic reference frame.
    private func oriented(_ point: SIMD3<Double>) -> SIMD3<Double> {
        let node = ascendingNodeDegrees * .pi / 180
        let periapsis = argumentOfPeriapsisDegrees * .pi / 180
        let inclination = inclinationDegrees * .pi / 180
        let along = SIMD3(cos(periapsis) * cos(node) - sin(periapsis) * sin(node) * cos(inclination),
                          cos(periapsis) * sin(node) + sin(periapsis) * cos(node) * cos(inclination),
                          sin(periapsis) * sin(inclination))
        let across = SIMD3(-sin(periapsis) * cos(node) - cos(periapsis) * sin(node) * cos(inclination),
                           -sin(periapsis) * sin(node) + cos(periapsis) * cos(node) * cos(inclination),
                           cos(periapsis) * sin(inclination))
        return along * point.x + across * point.y
    }

    static func solveKepler(mean: Double, eccentricity: Double) -> Double {
        var normalized = mean.remainder(dividingBy: 2 * .pi)
        if normalized < -.pi { normalized += 2 * .pi }
        var eccentric = eccentricity < 0.8 ? normalized : (normalized < 0 ? -Double.pi : Double.pi)
        for _ in 0..<16 {
            let correction = (eccentric - eccentricity * sin(eccentric) - normalized) /
                (1 - eccentricity * cos(eccentric))
            eccentric -= correction
            if abs(correction) < 1e-13 { return eccentric }
        }
        var lower = -Double.pi
        var upper = Double.pi
        for _ in 0..<64 {
            eccentric = (lower + upper) / 2
            if eccentric - eccentricity * sin(eccentric) < normalized {
                lower = eccentric
            } else {
                upper = eccentric
            }
        }
        return (lower + upper) / 2
    }
}

struct OrbitalState: Equatable, Sendable {
    /// Ecliptic km and km/s; rendering axis conversion is deliberately at the boundary.
    let position: SIMD3<Double>
    let velocity: SIMD3<Double>

    static func scenePosition(_ position: SIMD3<Double>) -> SIMD3<Float> {
        SIMD3<Float>(SIMD3(position.x, position.z, -position.y) * OrbitalElements.sceneUnitsPerKm)
    }
}
