import Foundation
import simd
import Testing
@testable import UniverseModule

private func ellipse(eccentricity: Double = 0.3, inclination: Double = 0,
                     node: Double = 0, periapsis: Double = 0) -> OrbitalElements {
    OrbitalElements(semiMajorAxisKm: 100_000, eccentricity: eccentricity,
                    inclinationDegrees: inclination, ascendingNodeDegrees: node,
                    argumentOfPeriapsisDegrees: periapsis, meanAnomalyDegrees: 0,
                    epochJulianDay: OrbitalElements.j2000, periodSeconds: 1_000)
}

@Test func keplerEllipseHasCorrectApsidesAndSpeed() {
    let orbit = ellipse()
    let periapsis = orbit.state(at: 0)
    let apoapsis = orbit.state(at: 500)
    #expect(abs(simd_length(periapsis.position) - 70_000) < 1e-8)
    #expect(abs(simd_length(apoapsis.position) - 130_000) < 1e-8)
    #expect(abs(simd_length(periapsis.velocity) / simd_length(apoapsis.velocity) - 1.3 / 0.7) < 1e-10)
    #expect(simd_distance(orbit.state(at: 1_000).position, periapsis.position) < 1e-8)
}

@Test func circularLimitAndCoordinateOrientation() {
    let circular = ellipse(eccentricity: 0)
    #expect(simd_distance(circular.state(at: 250).position, SIMD3(0, 100_000, 0)) < 1e-8)
    #expect(simd_distance(OrbitalState.scenePosition(circular.state(at: 250).position), SIMD3(0, 0, -0.1)) < 1e-7)
    #expect(simd_distance(ellipse(eccentricity: 0, inclination: 90).state(at: 250).position,
                          SIMD3(0, 0, 100_000)) < 1e-8)
    #expect(simd_distance(ellipse(eccentricity: 0, node: 90).state(at: 0).position,
                          SIMD3(0, 100_000, 0)) < 1e-8)
    #expect(simd_distance(ellipse(eccentricity: 0, periapsis: 90).state(at: 0).position,
                          SIMD3(0, 100_000, 0)) < 1e-8)
}

@Test func keplerEquationRemainsStableAtHighEccentricityAndManyPeriods() {
    for eccentricity in [0.0, 0.2, 0.9, 0.999999] {
        for mean in [-3.0, -0.01, 0, 0.001, 0.5, 3.0] {
            let anomaly = OrbitalElements.solveKepler(mean: mean, eccentricity: eccentricity)
            #expect(abs(anomaly - eccentricity * sin(anomaly) - mean) < 1e-12)
        }
    }
    let orbit = ellipse()
    #expect(simd_distance(orbit.state(at: 123).position,
                          orbit.state(at: 1_000 * 1_000_000_000 + 123).position) < 1e-7)
}

@Test func invalidOrbitalDataIsRejected() throws {
    let data = try JSONEncoder().encode(ellipse(eccentricity: 1.1))
    let orbitJSON = String(decoding: data, as: UTF8.self)
    let json = """
    [{"name":"Earth","meshName":"Earth","diameterKm":12756,"rotationSpeedKmSec":0,"orbit":\(orbitJSON)}]
    """
    #expect(throws: UniverseModulePreparationError.self) {
        try SolarSystemLoader.decodePlanets(from: Data(json.utf8))
    }
    #expect(!ellipse(eccentricity: -0.1).isValid)
}

@MainActor
@Test func moonPositionIsRelativeToMovingEarthAndStaleEpochsAreRejected() throws {
    let snapshot = orbitalTestSnapshot(time: 15 * 86_400)
    let earth = try #require(snapshot.worldPosition(ofPlanetNamed: "Earth"))
    let moon = try #require(snapshot.worldPosition(ofPlanetNamed: "Moon"))
    let moonOrbit = try #require(testPlanets.first { $0.name == "Moon" }?.orbit)
    #expect(simd_distance(moon - earth, OrbitalState.scenePosition(moonOrbit.state(at: snapshot.simulationTime).position)) < 1e-5)
    let pipeline = UniverseSceneSnapshotPipeline(planets: testPlanets)
    pipeline.requestPreparation(simulationTime: 20)
    pipeline.requestPreparation(simulationTime: 10)
    #expect(pipeline.latestSnapshot?.simulationTime == 20)
}

@Test func j2000StatesAgreeWithIndependentHorizonsReferencesWithinModelAccuracy() throws {
    // DE441 geometric J2000 ecliptic vectors, JPL Horizons, retrieved 2026-09-25.
    // Mean-element models intentionally have looser bounds than Pluto's osculating elements.
    let references: [(String, SIMD3<Double>, Double)] = [
        ("Mercury", SIMD3(-19_461_726.35585372, -66_913_275.263524, -3_679_854.343749542), 2_000),
        ("Earth", SIMD3(-26_499_033.67743050, 144_697_296.7925493, -611.1494259536266), 10_000),
        ("Moon", SIMD3(-291_608.3841877129, -274_979.7416731504, 36_271.19662699287), 5_000),
        ("Pluto", SIMD3(-1_477_331_666.009064, -4_182_576_442.612421, 875_214_251.751896), 0.001)
    ]
    for (name, expected, toleranceKm) in references {
        let orbit = try #require(testPlanets.first { $0.name == name }?.orbit)
        #expect(simd_distance(orbit.state(at: 0).position, expected) < toleranceKm)
    }
}
