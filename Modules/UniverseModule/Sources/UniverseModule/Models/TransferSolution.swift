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
    let earthOrbitPoints: [SIMD3<Float>]
    let destinationOrbitPoints: [SIMD3<Float>]

    var framingRadius: Float {
        (points + earthOrbitPoints + destinationOrbitPoints)
            .reduce(0) { max($0, simd_distance($1, sunPosition)) }
    }

    func position(at progress: Double) -> SIMD3<Float>? {
        guard let state = try? trajectory.state(after: min(1, max(0, progress)) * flightDuration) else { return nil }
        return sunPosition + OrbitalState.scenePosition(state.position)
    }

    static func make(destinationName: String, planets: [Planet],
                     departureEpoch: Double, sunPosition: SIMD3<Float> = .zero,
                     sampleCount: Int = 256) throws -> TransferSolution {
        guard sampleCount >= 2, departureEpoch.isFinite,
              let earth = planets.first(where: { $0.name == "Earth" })?.orbit,
              let destination = planets.first(where: { $0.name == destinationName }),
              destinationName != "Earth", destination.parentName == nil,
              let target = destination.orbit, earth.isValid, target.isValid else {
            throw TransferFailure.invalidGeometry
        }
        let transferAxis = (earth.semiMajorAxisKm + target.semiMajorAxisKm) / 2
        let duration = Double.pi * sqrt(pow(transferAxis, 3) / TwoBodyTrajectory.solarMu)
        let start = earth.state(at: departureEpoch).position
        let end = target.state(at: departureEpoch + duration).position
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
        let points = try (0..<sampleCount).map { index in
            let state = try trajectory.state(after: duration * Double(index) / Double(sampleCount - 1))
            return sunPosition + OrbitalState.scenePosition(state.position)
        }
        return TransferSolution(destinationName: destinationName, departureEpoch: departureEpoch,
                                flightDuration: duration, departureVelocity: velocities.departure,
                                arrivalVelocity: velocities.arrival, trajectory: trajectory,
                                sunPosition: sunPosition, points: points,
                                earthOrbitPoints: earth.orbitPoints().map { $0 + sunPosition },
                                destinationOrbitPoints: target.orbitPoints().map { $0 + sunPosition })
    }
}
