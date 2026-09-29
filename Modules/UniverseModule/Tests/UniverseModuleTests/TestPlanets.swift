import simd
@testable import UniverseModule

let testPlanets: [Planet] = (try? SolarSystemLoader.loadPlanets(from: "planets")) ?? []

// Small synthetic circular fixtures for camera and lunar geometry tests. Production has no
// legacy distance/angular-speed initializer; these units belong only to those test scenarios.
extension Planet {
    init(name: String, meshName: String, parentName: String?, radius: Float,
         distance: Float, orbitSpeed: Float, rotationSpeedKmSec: Float) {
        self.init(name: name, meshName: meshName, parentName: parentName, radius: radius,
                  orbit: distance > 0 ? OrbitalElements(
                    semiMajorAxisKm: Double(distance) / OrbitalElements.sceneUnitsPerKm,
                    eccentricity: 0, inclinationDegrees: 0, ascendingNodeDegrees: 0,
                    argumentOfPeriapsisDegrees: 0, meanAnomalyDegrees: 0,
                    epochJulianDay: OrbitalElements.j2000,
                    periodSeconds: orbitSpeed == 0 ? 1e30 : 2 * .pi / Double(orbitSpeed)
                  ) : nil, rotationSpeedKmSec: rotationSpeedKmSec)
    }

    var distance: Float { Float((orbit?.semiMajorAxisKm ?? 0) * OrbitalElements.sceneUnitsPerKm) }
}

@MainActor
func orbitalTestSnapshot(planets: [Planet] = testPlanets, time: Double = 0) -> UniverseSceneSnapshot {
    let pipeline = UniverseSceneSnapshotPipeline(planets: planets)
    pipeline.setPresentationMetrics(Dictionary(uniqueKeysWithValues: planets.map {
        ($0.name, CelestialBodyPresentationMetrics(renderRadius: $0.radius,
                                                   framingRadius: $0.radius, surfaceRadius: $0.radius))
    }))
    pipeline.requestPreparation(simulationTime: time)
    return pipeline.latestSnapshot ?? UniverseSceneSnapshot(frameID: 0, simulationTime: time, planets: [])
}
