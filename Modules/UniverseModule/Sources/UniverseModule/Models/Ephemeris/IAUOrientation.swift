import Foundation
import simd

struct IAUOrientation: Decodable, Sendable {
    struct Model: Decodable, Sendable {
        let poleRA: [Double]
        let poleDec: [Double]
        let meridian: [Double]
        let raTerms: [Double]
        let decTerms: [Double]
        let meridianTerms: [Double]
        let phasePolynomials: [[Double]]

        var isValid: Bool {
            let lists = [poleRA, poleDec, meridian, raTerms, decTerms, meridianTerms] + phasePolynomials
            return poleRA.count == 3 && poleDec.count == 3 && meridian.count == 3 &&
                lists.joined().allSatisfy(\.isFinite) &&
                [raTerms, decTerms, meridianTerms].allSatisfy { $0.count <= phasePolynomials.count }
        }

        /// IAU polynomials use centuries for the pole/phase and days for the meridian.
        func matrix(at seconds: Double) -> simd_double3x3 {
            let days = seconds / 86_400
            let centuries = days / 36_525
            func polynomial(_ coefficients: [Double], _ argument: Double) -> Double {
                coefficients.reversed().reduce(0) { $0 * argument + $1 }
            }
            let phases = phasePolynomials.map { polynomial($0, centuries) * .pi / 180 }
            let ra = (polynomial(poleRA, centuries) + zip(raTerms, phases).reduce(0) { $0 + $1.0 * sin($1.1) }) * .pi / 180
            let dec = (polynomial(poleDec, centuries) + zip(decTerms, phases).reduce(0) { $0 + $1.0 * cos($1.1) }) * .pi / 180
            let meridian = (polynomial(meridian, days) + zip(meridianTerms, phases).reduce(0) { $0 + $1.0 * sin($1.1) })
                .truncatingRemainder(dividingBy: 360) * .pi / 180
            // Equatorial basis: node is the ascending equator intersection, east lies in its plane.
            let node = SIMD3(-sin(ra), cos(ra), 0)
            let east = SIMD3(-sin(dec) * cos(ra), -sin(dec) * sin(ra), cos(dec))
            let pole = SIMD3(cos(dec) * cos(ra), cos(dec) * sin(ra), sin(dec))
            let equatorial = simd_double3x3(node * cos(meridian) + east * sin(meridian),
                                           -node * sin(meridian) + east * cos(meridian), pole)
            let obliquity = 84381.448 / 3600 * Double.pi / 180
            let equatorialToEcliptic = simd_double3x3(SIMD3(1, 0, 0), SIMD3(0, cos(obliquity), -sin(obliquity)),
                                                    SIMD3(0, sin(obliquity), cos(obliquity)))
            return equatorialToEcliptic * equatorial
        }
    }

    let bodies: [String: Model]
}
