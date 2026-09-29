import simd

/// Eleven analytic body states are inexpensive to prepare synchronously. Publishing the whole
/// snapshot before consumers run keeps bodies, route progress and cameras on one simulation epoch.
@MainActor
final class UniverseSceneSnapshotPipeline: UniverseSceneSnapshotProviding {
    private let planets: [Planet]
    private var nextFrameID: UInt64 = 0
    private var presentationTime: Float = 0
    private var presentationMetricsByBodyName: [String: CelestialBodyPresentationMetrics] = [:]
    private(set) var latestSnapshot: UniverseSceneSnapshot?

    init(planets: [Planet]) { self.planets = planets }

    func setPresentationTime(_ time: Float) { presentationTime = time }

    func setPresentationMetrics(_ metrics: [String: CelestialBodyPresentationMetrics]) {
        presentationMetricsByBodyName = metrics
    }

    func requestPreparation(simulationTime: Double) {
        guard simulationTime.isFinite,
              simulationTime >= (latestSnapshot?.simulationTime ?? -Double.infinity) else { return }
        var packets: [CelestialBodySnapshot] = []
        var worldPositionsByName: [String: SIMD3<Float>] = [:]
        for planet in planets {
            let parentPosition = planet.parentName.flatMap { worldPositionsByName[$0] }
            let orbitTransform = planet.orbitTransformMatrix(at: simulationTime, parentWorldPosition: parentPosition)
            let rotation = planet.visualRotationMatrix(at: presentationTime)
            let position = SIMD3<Float>(orbitTransform.columns.3.x, orbitTransform.columns.3.y, orbitTransform.columns.3.z)
            worldPositionsByName[planet.name] = position
            guard let metrics = presentationMetricsByBodyName[planet.name] else { continue }
            packets.append(CelestialBodySnapshot(planetName: planet.name,
                                                  baseModelMatrix: orbitTransform * rotation,
                                                  orbitTransformMatrix: orbitTransform,
                                                  visualRotationMatrix: rotation,
                                                  normalizedScale: planet.radius,
                                                  framingRadius: metrics.framingRadius,
                                                  surfaceRadius: metrics.surfaceRadius,
                                                  worldPosition: position))
        }
        latestSnapshot = UniverseSceneSnapshot(frameID: nextFrameID, simulationTime: simulationTime, planets: packets)
        nextFrameID += 1
    }
}
