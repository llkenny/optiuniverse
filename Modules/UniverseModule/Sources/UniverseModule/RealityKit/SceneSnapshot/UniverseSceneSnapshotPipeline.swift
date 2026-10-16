import simd

/// Eleven analytic body states are inexpensive to prepare synchronously. Publishing the whole
/// snapshot before consumers run keeps bodies, route progress and cameras on one simulation epoch.
@MainActor
final class UniverseSceneSnapshotPipeline: UniverseSceneSnapshotProviding {
    private let planets: [Planet]
    let stateProvider: any CelestialStateProviding
    private let usesEphemerisOrientation: Bool
    private(set) var preparationError: CelestialStateError?
    private var nextFrameID: UInt64 = 0
    private var presentationTime: Float = 0
    private var presentationMetricsByBodyName: [String: CelestialBodyPresentationMetrics] = [:]
    var hasPresentationMetrics: Bool { !presentationMetricsByBodyName.isEmpty }
    private(set) var latestSnapshot: UniverseSceneSnapshot?

    init(planets: [Planet], stateProvider: (any CelestialStateProviding)? = nil) {
        self.planets = planets
        self.stateProvider = stateProvider ?? KeplerCelestialStateProvider(planets: planets)
        usesEphemerisOrientation = stateProvider != nil
    }

    func setPresentationTime(_ time: Float) { presentationTime = time }

    func setPresentationMetrics(_ metrics: [String: CelestialBodyPresentationMetrics]) {
        presentationMetricsByBodyName = metrics
    }

    func requestPreparation(simulationTime: Double) {
        guard simulationTime.isFinite else { preparationError = .outsideCoverage; return }
        var packets: [CelestialBodySnapshot] = []
        for planet in planets {
            guard let body = CelestialBodyID(rawValue: planet.name) else { preparationError = .unknownBody; return }
            let state: CelestialBodyState
            do { state = try stateProvider.state(for: body, at: simulationTime) }
            catch { preparationError = (error as? CelestialStateError) ?? .invalidData; return }
            let position = SIMD3<Float>(state.scenePosition)
            let orbitTransform = float4x4.makeTranslation(position)
            let rotation = usesEphemerisOrientation ? state.sceneOrientation : planet.visualRotationMatrix(at: presentationTime)
            guard let metrics = presentationMetricsByBodyName[planet.name] else { continue }
            packets.append(CelestialBodySnapshot(planetName: planet.name,
                                                  baseModelMatrix: orbitTransform * rotation,
                                                  orbitTransformMatrix: orbitTransform,
                                                  visualRotationMatrix: rotation,
                                                  normalizedScale: planet.radius,
                                                  framingRadius: metrics.framingRadius,
                                                  surfaceRadius: metrics.surfaceRadius,
                                                  worldPosition: position,
                                                  preciseWorldPosition: state.scenePosition))
        }
        preparationError = nil
        latestSnapshot = UniverseSceneSnapshot(frameID: nextFrameID, simulationTime: simulationTime, planets: packets,
                                               stateProvider: stateProvider)
        nextFrameID += 1
    }
}
