import Foundation
import simd

struct Crew13FlightState: Sendable, Equatable {
    let dragon: MissionVehiclePose
    let firstStage: MissionVehiclePose
    let secondStage: MissionVehiclePose
    let station: MissionVehiclePose
    let firstStageVisible: Bool
    let secondStageVisible: Bool
    let firstStageThrust: Float
    let secondStageThrust: Float
    let noseConeOpen: Float
    let status: MissionNavigationStatus
}

/// Illustrative launch and rendezvous in a frame captured at liftoff. Earth translation
/// follows scene snapshots; decorative Earth spin never changes the captured orbital plane.
struct Crew13RouteProfile: Sendable, Equatable {
    static let duration: TimeInterval = 60
    // These local offsets are also used to build the geometry and align the docking ports.
    static let dragonDockingOffset = SIMD3<Float>(0, 0.5, 0)
    static let stationDockingOffset = SIMD3<Float>(0, 0.65, 0)
    let center: SIMD3<Float>
    let radius: Float
    let launchDirection: SIMD3<Float>
    let heading: SIMD3<Float>
    let normal: SIMD3<Float>

    var vehicleScale: Float { radius * 0.06 }
    var stationScale: Float { radius * 0.09 }
    var dockingDistance: Float {
        Self.dragonDockingOffset.y * vehicleScale + Self.stationDockingOffset.y * stationScale
    }

    init?(earth: CelestialBodySnapshot) {
        guard earth.surfaceRadius.isFinite, earth.surfaceRadius > 0,
              Self.isFinite(earth.worldPosition) else { return nil }
        let coordinate = SurfaceCoordinate(latitudeDegrees: 28.562, longitudeDegrees: -80.577)
        let surface = SurfaceCoordinateMath.localUnitVector(for: coordinate)
        let longitude = coordinate.longitudeDegrees * .pi / 180
        let east = SIMD3<Float>(-sin(longitude), 0, cos(longitude))
        let north = cross(east, surface)
        let rotation = earth.visualRotationMatrix
        let launch = rotation * SIMD4<Float>(surface, 0)
        let direction = rotation * SIMD4<Float>(normalize(east * 0.75 + north * 0.66), 0)
        let radial = SIMD3<Float>(launch.x, launch.y, launch.z)
        let tangent = SIMD3<Float>(direction.x, direction.y, direction.z)
        guard Self.isFinite(radial), Self.isFinite(tangent), length(radial) > 0.001,
              length(cross(radial, tangent)) > 0.001 else { return nil }
        center = earth.worldPosition
        radius = earth.surfaceRadius
        launchDirection = normalize(radial)
        normal = normalize(cross(radial, tangent))
        heading = normalize(cross(normal, launchDirection))
    }

    func translated(to center: SIMD3<Float>) -> Self {
        Self(center: center, radius: radius, launchDirection: launchDirection, heading: heading, normal: normal)
    }

    private init(center: SIMD3<Float>, radius: Float, launchDirection: SIMD3<Float>,
                 heading: SIMD3<Float>, normal: SIMD3<Float>) {
        self.center = center
        self.radius = radius
        self.launchDirection = launchDirection
        self.heading = heading
        self.normal = normal
    }

    func dragonPosition(time: Double) -> SIMD3<Float> {
        let time = Self.clampedTime(time)
        if time < 18 {
            let fraction = Self.smooth(Float(time / 18))
            return center + direction(angle: 0.7 * fraction) * radius * (1.33 + 0.17 * fraction)
        }
        if time < 36 {
            return center + direction(angle: orbitalAngle(time: time)) * radius * 1.5
        }
        let stationAngle = stationAngle(time: time)
        let radial = direction(angle: stationAngle)
        let tangent = cross(normal, radial)
        let approach = Self.smooth(Float((time - 36) / 22))
        // Express the approach in the moving station frame. It starts at Dragon's
        // orbital position and ends exactly one pair of docking offsets behind ISS.
        let initialRadial = radius * 1.5 * (cos(Float(0.55)) - 1)
        let initialTrailing = radius * 1.5 * sin(Float(0.55))
        return center + radial * (radius * 1.5 + initialRadial * (1 - approach))
            - tangent * (initialTrailing * (1 - approach) + dockingDistance * approach)
    }

    func sample(time: Double) -> Crew13FlightState {
        let time = Self.clampedTime(time)
        let dragonPosition = dragonPosition(time: time)
        let radial = normalize(dragonPosition - center)
        let tangent = normalize(cross(normal, radial))
        let pitch = Self.smooth(Float(time / 18))
        let launchAxis = normalize(radial * (1 - pitch) + tangent * pitch)
        let stationRadial = direction(angle: stationAngle(time: time))
        let stationTangent = normalize(cross(normal, stationRadial))
        let alignment = Self.smooth(Float((time - 36) / 12))
        let dragonAxis = normalize(launchAxis * (1 - alignment) + stationTangent * alignment)
        let dragon = pose(position: dragonPosition, axis: dragonAxis)
        let station = pose(position: center + stationRadial * radius * 1.5, axis: -stationTangent)
        let boosterSeparation = Self.smooth(Float((time - 8) / 6))
        let stageSeparation = Self.smooth(Float((time - 16) / 6))
        let firstStage = pose(
            position: dragonPosition - dragonAxis * vehicleScale * 3.41
                - radial * radius * 0.15 * boosterSeparation
                - normal * radius * 0.08 * boosterSeparation,
            axis: normalize(dragonAxis + normal * boosterSeparation * 0.4))
        let secondStage = pose(
            position: dragonPosition - dragonAxis * vehicleScale * 1.11
                - radial * radius * 0.22 * stageSeparation
                + normal * radius * 0.08 * stageSeparation,
            axis: normalize(dragonAxis - normal * stageSeparation * 0.3))
        return Crew13FlightState(
            dragon: dragon, firstStage: firstStage, secondStage: secondStage, station: station,
            firstStageVisible: time < 14, secondStageVisible: time < 22,
            firstStageThrust: time < 8 ? 1 : 0,
            secondStageThrust: time >= 8 && time < 16 ? 1 : 0,
            noseConeOpen: Self.smooth(Float((time - 30) / 6)), status: status(time: time))
    }

    func status(time: Double) -> MissionNavigationStatus {
        let phase: MissionNavigationStatus.Phase
        switch Self.clampedTime(time) {
        case ..<8: phase = .launch
        case ..<10: phase = .separation
        case ..<16: phase = .secondStageBurn
        case ..<18: phase = .dragonSeparation
        case ..<36: phase = .orbit
        case ..<48: phase = .rendezvous
        case ..<58: phase = .docking
        default: phase = .docked
        }
        return MissionNavigationStatus(mission: .crew13, phase: phase, currentOrbit: 0,
                                       totalOrbits: 0, deployedSatelliteCount: 0)
    }

    func makeRoute(id: UUID = UUID()) -> NavigationRoute {
        let points = (0...480).map { dragonPosition(time: Double($0) / 8) }
        let distances = RoutePathBuilder.makeCumulativeDistances(points: points)
        return NavigationRoute(id: id, originName: "Earth", destinationName: "ISS", points: points,
                               cumulativeDistances: distances, totalDistance: distances.last ?? 0,
                               estimatedDuration: Self.duration, overviewPaddingRadius: radius * 1.9,
                               overviewCenter: center, mission: .crew13, crew13Profile: self)
    }

    private func direction(angle: Float) -> SIMD3<Float> {
        launchDirection * cos(angle) + heading * sin(angle)
    }

    private func orbitalAngle(time: Double) -> Float {
        0.7 + Float((time - 18) / 24) * 2 * .pi
    }

    private func stationAngle(time: Double) -> Float {
        // Start the compressed orbital clock with ascent so the station stays ahead
        // of Dragon instead of sweeping through the launch stack before insertion.
        let angle = time < 18 ? 0.7 * Self.smooth(Float(time / 18)) : orbitalAngle(time: time)
        return angle + 0.55
    }

    private func pose(position: SIMD3<Float>, axis: SIMD3<Float>) -> MissionVehiclePose {
        let right = normalize(cross(axis, normal))
        return MissionVehiclePose(position: position,
                                  orientation: simd_quatf(simd_float3x3(columns: (right, axis, cross(right, axis)))))
    }

    static func smooth(_ value: Float) -> Float {
        let value = min(1, max(0, value))
        return value * value * (3 - 2 * value)
    }

    private static func clampedTime(_ time: Double) -> Double {
        min(duration, max(0, time.isFinite ? time : 0))
    }

    private static func isFinite(_ value: SIMD3<Float>) -> Bool {
        value.x.isFinite && value.y.isFinite && value.z.isFinite
    }
}
