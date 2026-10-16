import Foundation
import simd

struct TransferSolution: Equatable, Sendable {
    static let playbackDuration = 30.0
    let destinationName: String
    let departureEpoch: Double
    let flightDuration: Double
    var arrivalEpoch: Double { departureEpoch + flightDuration }
    let departureVelocity: SIMD3<Double>
    let arrivalVelocity: SIMD3<Double>
    let trajectory: TwoBodyTrajectory
    let sunPosition: SIMD3<Float>
    let points: [SIMD3<Float>]
    let precisePoints: [SIMD3<Double>]
    let preciseEarthOrbitPoints: [SIMD3<Double>]
    let preciseDestinationOrbitPoints: [SIMD3<Double>]
    let hasPartialDestinationOrbit: Bool
    let earthOrbitPoints: [SIMD3<Float>]
    let destinationOrbitPoints: [SIMD3<Float>]

    var framingRadius: Float {
        (points + earthOrbitPoints + destinationOrbitPoints)
            .reduce(0) { max($0, simd_distance($1, sunPosition)) }
    }

    func position(at progress: Double) -> SIMD3<Float>? {
        precisePosition(at: progress).map { SIMD3<Float>($0) }
    }

    func precisePosition(at progress: Double) -> SIMD3<Double>? {
        guard let state = try? trajectory.state(after: min(1, max(0, progress)) * flightDuration) else { return nil }
        return SIMD3<Double>(sunPosition) + EphemerisCoordinates.scenePosition(state.position)
    }

    static func make(destinationName: String, planets: [Planet],
                     departureEpoch: Double, sunPosition: SIMD3<Float> = .zero,
                     sampleCount: Int = 256,
                     stateProvider: (any CelestialStateProviding)? = nil) throws -> TransferSolution {
        guard sampleCount >= 2, departureEpoch.isFinite,
              let earth = planets.first(where: { $0.name == "Earth" })?.orbit,
              let destination = planets.first(where: { $0.name == destinationName }),
              destinationName != "Earth", destination.parentName == nil,
              let target = destination.orbit, earth.isValid, target.isValid else {
            throw TransferFailure.invalidGeometry
        }
        let transferAxis = (earth.semiMajorAxisKm + target.semiMajorAxisKm) / 2
        let duration = Double.pi * sqrt(pow(transferAxis, 3) / TwoBodyTrajectory.solarMu)
        let provider = stateProvider ?? KeplerCelestialStateProvider(planets: planets)
        guard let targetID = CelestialBodyID(rawValue: destinationName) else { throw TransferFailure.invalidGeometry }
        let start: SIMD3<Double>
        let end: SIMD3<Double>
        do {
            start = try provider.state(for: .earth, at: departureEpoch).positionKm
            end = try provider.state(for: targetID, at: departureEpoch + duration).positionKm
        } catch { throw TransferFailure.ephemerisUnavailable }
        let velocities = try LambertSolver.solve(from: start, to: end, duration: duration,
                                                  mu: TwoBodyTrajectory.solarMu)
        let trajectory = TwoBodyTrajectory(initialPosition: start,
                                            initialVelocity: velocities.departure,
                                            mu: TwoBodyTrajectory.solarMu)
        guard trajectory.minimumRadius(endingAt: end) > 695_700 else { throw TransferFailure.intersectsSun }
        let propagatedEnd = try trajectory.state(after: duration).position
        guard simd_distance(propagatedEnd, end) < max(0.1, simd_length(end) * 1e-9) else {
            throw TransferFailure.didNotConverge
        }
        let precisePoints = try (0..<sampleCount).map { index in
            let state = try trajectory.state(after: duration * Double(index) / Double(sampleCount - 1))
            return SIMD3<Double>(sunPosition) + EphemerisCoordinates.scenePosition(state.position)
        }
        let earthPoints: [SIMD3<Double>]
        let targetPoints: [SIMD3<Double>]
        if stateProvider != nil {
            do {
                earthPoints = try EphemerisOrbitPath.points(for: .earth, period: earth.periodSeconds, at: departureEpoch,
                                                           provider: provider, origin: SIMD3<Double>(sunPosition))
                targetPoints = try EphemerisOrbitPath.points(for: targetID, period: target.periodSeconds, at: departureEpoch,
                                                            provider: provider, origin: SIMD3<Double>(sunPosition))
            } catch { throw TransferFailure.ephemerisUnavailable }
        } else {
            earthPoints = earth.orbitPoints().map { SIMD3<Double>($0 + sunPosition) }
            targetPoints = target.orbitPoints().map { SIMD3<Double>($0 + sunPosition) }
        }
        return TransferSolution(destinationName: destinationName, departureEpoch: departureEpoch,
                                flightDuration: duration, departureVelocity: velocities.departure,
                                arrivalVelocity: velocities.arrival, trajectory: trajectory,
                                sunPosition: sunPosition, points: precisePoints.map { SIMD3<Float>($0) },
                                precisePoints: precisePoints, preciseEarthOrbitPoints: earthPoints,
                                preciseDestinationOrbitPoints: targetPoints,
                                hasPartialDestinationOrbit: provider.coverage.map {
                                    target.periodSeconds > $0.upperBound - $0.lowerBound
                                } ?? false,
                                earthOrbitPoints: earthPoints.map { SIMD3<Float>($0) },
                                destinationOrbitPoints: targetPoints.map { SIMD3<Float>($0) })
    }
}
