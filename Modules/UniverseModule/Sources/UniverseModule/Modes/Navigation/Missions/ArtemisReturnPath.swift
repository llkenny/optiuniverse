import Foundation
import simd

/// A schematic direct entry: approach the limb, then descend along a short atmospheric arc.
struct ArtemisReturnPath {
    private struct CubicApproach {
        let start: SIMD3<Float>
        let controlA: SIMD3<Float>
        let controlB: SIMD3<Float>
        let end: SIMD3<Float>
    }

    let center: SIMD3<Float>
    let surfaceRadius: Float
    let majorDirection: SIMD3<Float>
    let sideDirection: SIMD3<Float>
    let controlScale: Float

    func makePoints(start: SIMD3<Float>, controlA: SIMD3<Float>, sampleCount: Int) -> [SIMD3<Float>] {
        // The launch path's fallback minor axis can be parallel to a vertical Earth–Moon axis.
        // Entry needs an orthonormal plane so its radial distance remains the requested radius.
        let projectedSide = sideDirection - majorDirection * simd_dot(sideDirection, majorDirection)
        let side = simd_length_squared(projectedSide) > 0.000_001
            ? normalize(projectedSide) : SIMD3<Float>(1, 0, 0)
        let radius = surfaceRadius.isFinite && surfaceRadius > 0 ? surfaceRadius : 0
        let entry = -side * radius * ArtemisRouteProfile.entryRadiusScale
        let descentAngle = ArtemisRouteProfile.entryDescentAngle
        let radialDrop = radius * (ArtemisRouteProfile.entryRadiusScale - 1)
        // Match the derivative of the polar descent, including its small inward component.
        let entryDerivative = -majorDirection * radius * ArtemisRouteProfile.entryRadiusScale * descentAngle
            + side * radialDrop
        let controlB: SIMD3<Float>
        if radius > 0 {
            controlB = entry - normalize(entryDerivative) * controlScale * 0.38
        } else {
            // A scene without presentation metrics still has a usable Earth–Moon–Earth route.
            controlB = majorDirection * controlScale * 0.38
                - side * controlScale * ArtemisRouteProfile.returnBranchLateralScale
                + SIMD3<Float>(0, 1, 0) * controlScale * 0.015
        }

        // Subdivide in Earth-local coordinates: atmospheric heights are tiny compared to world positions.
        var points = [start - center]
        appendApproach(CubicApproach(start: start - center, controlA: controlA - center,
                                     controlB: controlB, end: entry),
                       minimumSegments: max(sampleCount - 1, 1), depth: 0, to: &points)
        if radius > 0 {
            // Limit chord sag as well as angular resolution. With a linear radial drop,
            // this bound keeps even the last chord outside the surface until touchdown.
            let maximumAngle = min(ArtemisRouteProfile.maximumDescentSampleAngle,
                                   radialDrop / (radius * ArtemisRouteProfile.entryRadiusScale * descentAngle))
            let segments = max(1, Int(ceil(descentAngle / maximumAngle)))
            for index in 1...segments {
                let progress = Float(index) / Float(segments)
                let angle = descentAngle * progress
                let descendingRadius = radius * ArtemisRouteProfile.entryRadiusScale - radialDrop * progress
                points.append((-side * cos(angle) - majorDirection * sin(angle)) * descendingRadius)
            }
        }
        return points.map { center + $0 }
    }

    private func appendApproach(_ curve: CubicApproach,
                                minimumSegments: Int, depth: Int, to points: inout [SIMD3<Float>]) {
        let start = curve.start
        let controlA = curve.controlA
        let controlB = curve.controlB
        let end = curve.end
        let first = (start + controlA) * 0.5
        let middle = (controlA + controlB) * 0.5
        let last = (controlB + end) * 0.5
        let leftControl = (first + middle) * 0.5
        let rightControl = (middle + last) * 0.5
        let midpoint = (leftControl + rightControl) * 0.5
        let tolerance = max(surfaceRadius * 0.001, controlScale * 0.000_001)
        let polygonLength = simd_distance(start, controlA) + simd_distance(controlA, controlB)
            + simd_distance(controlB, end)
        let chordLength = simd_distance(start, end)
        let nearEarth = surfaceRadius > 0 && min(simd_length(start), simd_length(end)) < surfaceRadius * 2
        let needsSubdivision = minimumSegments > 1 || polygonLength - chordLength > tolerance
            || (nearEarth && chordLength > surfaceRadius * 0.05)
        guard needsSubdivision, depth < 12 else {
            points.append(end)
            return
        }
        let halfSegments = (minimumSegments + 1) / 2
        appendApproach(CubicApproach(start: start, controlA: first, controlB: leftControl, end: midpoint),
                       minimumSegments: halfSegments, depth: depth + 1, to: &points)
        appendApproach(CubicApproach(start: midpoint, controlA: rightControl, controlB: last, end: end),
                       minimumSegments: halfSegments, depth: depth + 1, to: &points)
    }
}
