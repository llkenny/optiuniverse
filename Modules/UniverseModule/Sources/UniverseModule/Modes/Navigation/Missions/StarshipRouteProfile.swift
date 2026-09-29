import Foundation
import simd

struct MissionVehiclePose: Sendable, Equatable {
    let position: SIMD3<Float>
    let orientation: simd_quatf
}

struct StarshipFlightState: Sendable, Equatable {
    let ship: MissionVehiclePose
    let booster: MissionVehiclePose
    let satellites: [MissionVehiclePose]
    let status: MissionNavigationStatus
    let shipThrust: Float
    let boosterThrust: Float
    let reentryGlow: Float
    let boosterVisible: Bool
}

/// A cinematic Earth-relative flight, not an ephemeris or a physical launch simulation.
/// The orbital basis is captured at launch so decorative Earth spin cannot rotate the orbit.
struct StarshipRouteProfile: Sendable, Equatable {
    static let duration: TimeInterval = 60
    static let satelliteCount = 26
    static let orbitCount = 2
    let center: SIMD3<Float>
    let radius: Float
    let launchDirection: SIMD3<Float>
    let east: SIMD3<Float>
    let normal: SIMD3<Float>

    init?(earth: CelestialBodySnapshot) {
        guard earth.surfaceRadius.isFinite, earth.surfaceRadius > 0,
              earth.worldPosition.x.isFinite, earth.worldPosition.y.isFinite,
              earth.worldPosition.z.isFinite else { return nil }
        center = earth.worldPosition
        radius = earth.surfaceRadius
        // Starbase, expressed in the same rotating surface frame as the Earth asset.
        let coordinate = SurfaceCoordinate(latitudeDegrees: 25.997, longitudeDegrees: -97.156)
        let longitude = coordinate.longitudeDegrees * .pi / 180
        let surface = SurfaceCoordinateMath.localUnitVector(for: coordinate)
        let tangent = SIMD3<Float>(-sin(longitude), 0, cos(longitude))
        let rotation = earth.visualRotationMatrix
        let launch = rotation * SIMD4<Float>(surface, 0)
        let heading = rotation * SIMD4<Float>(tangent, 0)
        launchDirection = normalize(SIMD3<Float>(launch.x, launch.y, launch.z))
        east = normalize(SIMD3<Float>(heading.x, heading.y, heading.z))
        normal = normalize(cross(launchDirection, east))
    }

    private init(center: SIMD3<Float>, radius: Float, launchDirection: SIMD3<Float>,
                 east: SIMD3<Float>, normal: SIMD3<Float>) {
        self.center = center
        self.radius = radius
        self.launchDirection = launchDirection
        self.east = east
        self.normal = normal
    }

    func translated(to center: SIMD3<Float>) -> Self {
        Self(center: center, radius: radius, launchDirection: launchDirection, east: east, normal: normal)
    }

    func direction(angle: Float) -> SIMD3<Float> {
        launchDirection * cos(angle) + east * sin(angle)
    }

    func orbitalAngle(time: Double) -> Float {
        0.35 + Float((time - 16) / 14) * 2 * .pi
    }

    func shipPosition(time: Double) -> SIMD3<Float> {
        let time = min(60, max(0, time))
        let angle: Float
        let altitude: Float
        if time < 16 {
            let fraction = Float(time / 16)
            angle = 0.35 * fraction * fraction
            altitude = 1.1611 + 0.2389 * Self.smooth(fraction)
        } else if time <= 44 {
            angle = orbitalAngle(time: time)
            altitude = 1.4
        } else {
            let fraction = Float((time - 44) / 16)
            // Illustrative downrange descent; the orbit remains in the captured launch frame.
            angle = orbitalAngle(time: 44) + 4.5 * Self.smooth(fraction)
            altitude = 1.4 - 0.35 * Self.smooth(fraction)
        }
        return center + direction(angle: angle) * (radius * altitude)
    }

    func sample(time: Double) -> StarshipFlightState {
        let time = min(60, max(0, time.isFinite ? time : 0))
        let shipPosition = shipPosition(time: time)
        let radial = normalize(shipPosition - center)
        let tangent = normalize(cross(normal, radial))
        let pitch = time < 16 ? Self.smooth(Float(time / 16)) : 1 - Self.smooth(Float((time - 53) / 6))
        let shipAxis = normalize(radial * (1 - pitch) + tangent * pitch)
        let ship = pose(position: shipPosition, axis: shipAxis)
        let booster: MissionVehiclePose
        if time <= 8 {
            booster = pose(position: shipPosition - shipAxis * radius * 0.0972, axis: shipAxis)
        } else {
            let fraction = Float(min(1, (time - 8) / 8))
            let separation = sampleStackAtSeparation()
            let start = separation.position - center
            let startRadius = length(start) / radius
            let startAngle: Float = atan2(dot(start, east), dot(start, launchDirection))
            let returnRadial = direction(angle: startAngle + 0.18 * Self.smooth(fraction))
            let height = startRadius + (1.065 - startRadius) * Self.smooth(fraction)
                + 0.12 * sin(.pi * fraction)
            booster = MissionVehiclePose(
                position: center + returnRadial * radius * height,
                orientation: simd_slerp(separation.orientation,
                                        pose(position: .zero, axis: returnRadial).orientation,
                                        Self.smooth(fraction)))
        }
        let status = status(time: time)
        let deployed = status.deployedSatelliteCount
        let satellites = (0..<deployed).map { index -> MissionVehiclePose in
            let releaseTime = 19 + Double(index) * 0.36
            let age = Float(time - releaseTime)
            // A small differential angular speed produces a persistent, spreading train.
            let angle = orbitalAngle(time: time) - min(age, 6) * 0.024 - age * 0.006
            let satelliteRadial = direction(angle: angle)
            let position = center + satelliteRadial * radius * (1.4 + min(age, 4) * 0.004)
                - normal * radius * (0.009 + min(age, 3) * 0.012)
            return pose(position: position, axis: normalize(cross(normal, satelliteRadial)))
        }
        return StarshipFlightState(
            ship: ship, booster: booster, satellites: satellites,
            status: status,
            shipThrust: time < 8 ? 0 : (time < 16 || (time >= 44 && time < 46) || (time >= 56 && time < 60) ? 1 : 0),
            boosterThrust: time < 8 || (time >= 13 && time < 16) ? 1 : 0,
            reentryGlow: Self.smooth(Float((time - 46) / 3)) * (1 - Self.smooth(Float((time - 54) / 3))),
            boosterVisible: time < 19)
    }

    func status(time: Double) -> MissionNavigationStatus {
        let time = min(60, max(0, time.isFinite ? time : 0))
        let deployed = min(Self.satelliteCount, max(0, Int(floor((time - 19) / 0.36)) + 1))
        return MissionNavigationStatus(mission: .starshipFlight14, phase: phase(time: time),
                                       currentOrbit: time < 16 ? 0 : (time < 30 ? 1 : 2),
                                       totalOrbits: Self.orbitCount, deployedSatelliteCount: deployed)
    }

    private func sampleStackAtSeparation() -> MissionVehiclePose {
        let position = shipPosition(time: 8)
        let radial = normalize(position - center)
        let axis = normalize(radial + cross(normal, radial))
        return pose(position: position - axis * radius * 0.0972, axis: axis)
    }

    private func phase(time: Double) -> MissionNavigationStatus.Phase {
        switch time {
        case ..<8: .launch
        case ..<10: .separation
        case ..<16: .boosterReturn
        case 19..<28.4: .deployment
        case ..<44: .orbit
        case ..<46: .deorbit
        case ..<56: .reentry
        case ..<60: .landing
        default: .splashdown
        }
    }

    private func pose(position: SIMD3<Float>, axis: SIMD3<Float>) -> MissionVehiclePose {
        let right = normalize(cross(axis, normal))
        return MissionVehiclePose(position: position,
                                  orientation: simd_quatf(simd_float3x3(columns: (right, axis, normal))))
    }

    func makeRoute(id: UUID = UUID()) -> NavigationRoute {
        let points = (0...480).map { shipPosition(time: Double($0) / 8) }
        let distances = RoutePathBuilder.makeCumulativeDistances(points: points)
        return NavigationRoute(id: id, originName: "Earth", destinationName: "Earth", points: points,
                               cumulativeDistances: distances, totalDistance: distances.last ?? 0,
                               estimatedDuration: Self.duration, overviewPaddingRadius: radius * 1.6,
                               overviewCenter: center, mission: .starshipFlight14, starshipProfile: self)
    }

    static func smooth(_ value: Float) -> Float {
        let value = min(1, max(0, value))
        return value * value * (3 - 2 * value)
    }
}
