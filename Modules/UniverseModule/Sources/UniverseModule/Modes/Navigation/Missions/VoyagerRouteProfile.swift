import Foundation
import simd

struct VoyagerFlightState: Sendable, Equatable {
    let probe: MissionVehiclePose
    let rocket: MissionVehiclePose
    let centaur: MissionVehiclePose
    let vehicleScale: Float
    let rocketScale: Float
    let focusCenter: SIMD3<Double>
    let focusRadius: Float
    let closeUpWeight: Float
    let status: MissionNavigationStatus
}

/// Prepared once per launch; frame updates interpolate immutable samples without
/// querying ephemerides, rebuilding route geometry, or rounding absolute positions to Float.
struct VoyagerRouteProfile: Sendable, Equatable {
    static let duration = 90.0
    private static let sampleRate = 16.0
    struct Sample: Sendable, Equatable {
        let position: SIMD3<Double>
        let earth: SIMD3<Double>
        let focus: SIMD3<Double>
        let radius: Float
    }
    let samples: [Sample]
    let velocities: [SIMD3<Double>]
    let accelerations: [SIMD3<Double>]
    let earthRadius: Float
    let launchDirection: SIMD3<Double>

    init(snapshot: UniverseSceneSnapshot) throws {
        guard let provider = snapshot.stateProvider else { throw TransferFailure.ephemerisUnavailable }
        let geometry = try VoyagerRouteGeometry(snapshot: snapshot, provider: provider)
        let earthRadius = geometry.earth.surfaceRadius
        self.earthRadius = earthRadius
        launchDirection = geometry.launchDirection
        samples = try (0...Int(Self.duration * Self.sampleRate)).map { index in
            let time = Double(index) / Self.sampleRate
            let focus: SIMD3<Double>
            let radius: Float
            switch time {
            case ..<20: focus = try geometry.body(.earth, time: time); radius = earthRadius
            case ..<41: focus = try geometry.body(.jupiter, time: time); radius = geometry.jupiterRadius
            case ..<64: focus = try geometry.body(.saturn, time: time); radius = geometry.saturnRadius
            default: focus = try geometry.position(time: time); radius = earthRadius
            }
            return Sample(position: try geometry.position(time: time), earth: try geometry.body(.earth, time: time),
                          focus: focus, radius: radius)
        }
        let positions = samples.map(\.position)
        velocities = positions.indices.map { index in
            guard index > 0, Double(index) / Self.sampleRate < 82 else { return .zero }
            let upper = min(index + 1, positions.count - 1)
            return (positions[upper] - positions[index - 1]) * Self.sampleRate / Double(upper - index + 1)
        }
        accelerations = positions.indices.map { index in
            guard index > 0, Double(index) / Self.sampleRate < 82 else { return .zero }
            return (positions[index + 1] - 2 * positions[index] + positions[index - 1])
                * Self.sampleRate * Self.sampleRate
        }
    }

    func precisePosition(time: Double) -> SIMD3<Double> {
        let (index, fraction) = sampleIndex(time: time)
        return VoyagerRouteGeometry.interpolate(
            from: .init(position: samples[index].position, velocity: velocities[index],
                        acceleration: accelerations[index]),
            to: .init(position: samples[index + 1].position, velocity: velocities[index + 1],
                      acceleration: accelerations[index + 1]),
            duration: 1 / Self.sampleRate, fraction: fraction)
    }

    func sample(time: Double) -> VoyagerFlightState {
        let time = Self.clampedTime(time)
        let (index, fraction) = sampleIndex(time: time)
        let left = samples[index]
        let right = samples[index + 1]
        let position = precisePosition(time: time)
        let earth = left.earth + (right.earth - left.earth) * fraction
        let focus = left.focus + (right.focus - left.focus) * fraction
        let weight = Self.closeUpWeight(time: time)
        let radius = left.radius + (right.radius - left.radius) * Float(fraction)
        let cruiseScale = max(earthRadius * 0.04, Float(length(position)) * 0.02)
        let localScale = time < 20 ? earthRadius * 0.025 : radius * 0.18
        let scale = max(0.001, cruiseScale * (1 - weight) + localScale * weight)
        let launchOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: SIMD3<Float>(launchDirection))
        let earthOrientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: SIMD3<Float>(normalize(earth - position)))
        let orientation = simd_slerp(launchOrientation, earthOrientation, Self.smooth((time - 15) / 3))
        let rocketScale = earthRadius * 0.1
        let separation = Double(Self.smooth((time - 8) / 5))
        let centaurSeparation = Double(Self.smooth((time - 12) / 3))
        return VoyagerFlightState(
            probe: pose(position, orientation: orientation),
            rocket: pose(position - launchDirection * Double(rocketScale) * (2.4 + 7 * separation),
                         orientation: launchOrientation),
            centaur: pose(position - launchDirection * Double(rocketScale) * (0.8 + 3 * centaurSeparation),
                          orientation: launchOrientation),
            vehicleScale: scale, rocketScale: rocketScale, focusCenter: focus, focusRadius: radius,
            closeUpWeight: weight, status: status(time: time))
    }

    func status(time: Double) -> MissionNavigationStatus {
        let phase: MissionNavigationStatus.Phase
        switch Self.clampedTime(time) {
        case ..<8: phase = .launch
        case ..<15: phase = .separation
        case ..<24: phase = .interplanetaryCruise
        case ..<36: phase = .jupiterFlyby
        case ..<46: phase = .interplanetaryCruise
        case ..<58: phase = .saturnFlyby
        case ..<82: phase = .interstellarCruise
        default: phase = .interstellarSpace
        }
        return MissionNavigationStatus(mission: .voyager1, phase: phase, currentOrbit: 0,
                                       totalOrbits: 0, deployedSatelliteCount: 0)
    }

    func makeRoute(id: UUID = UUID()) -> NavigationRoute {
        let points = samples.map(\.position)
        let distances = RoutePathBuilder.makeCumulativeDistances(precisePoints: points)
        return NavigationRoute(id: id, originName: "Earth", destinationName: "Interstellar space",
                               points: points.map { SIMD3<Float>($0) }, cumulativeDistances: distances,
                               totalDistance: distances.last ?? 0, estimatedDuration: Self.duration,
                               overviewPaddingRadius: Float(length(points.last ?? .zero)), overviewCenter: .zero,
                               precisePoints: points, preciseOverviewCenter: .zero,
                               mission: .voyager1, voyagerProfile: self)
    }

    private func sampleIndex(time: Double) -> (Int, Double) {
        let sample = Self.clampedTime(time) * Self.sampleRate
        let index = min(Int(sample), samples.count - 2)
        return (index, sample - Double(index))
    }

    private func pose(_ position: SIMD3<Double>, orientation: simd_quatf) -> MissionVehiclePose {
        MissionVehiclePose(position: .zero, orientation: orientation, precisePosition: position)
    }

    static func closeUpWeight(time: Double) -> Float {
        if time < 20 { return 1 - smooth((time - 15) / 5) }
        if time < 41 { return smooth((time - 20) / 4) * (1 - smooth((time - 36) / 4)) }
        if time < 64 { return smooth((time - 42) / 4) * (1 - smooth((time - 58) / 5)) }
        return smooth((time - 77) / 5)
    }

    static func smooth(_ value: Double) -> Float {
        let unit = Float(min(1, max(0, value)))
        return unit * unit * (3 - 2 * unit)
    }

    private static func clampedTime(_ time: Double) -> Double { time.isFinite ? min(90, max(0, time)) : 0 }
}
