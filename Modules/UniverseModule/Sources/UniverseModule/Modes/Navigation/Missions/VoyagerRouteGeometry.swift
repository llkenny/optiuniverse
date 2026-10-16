import Foundation
import simd

/// Cinematic curves in absolute double-precision scene coordinates. The quintic
/// segments agree in position, velocity and acceleration, including at moving flybys.
struct VoyagerRouteGeometry {
    struct Boundary {
        let position: SIMD3<Double>
        var velocity: SIMD3<Double> = .zero
        var acceleration: SIMD3<Double> = .zero
    }

    let earth: CelestialBodySnapshot
    let jupiterRadius: Float
    let saturnRadius: Float
    let launchDirection: SIMD3<Double>
    let launchHeading: SIMD3<Double>
    private let jupiterIncoming: SIMD3<Double>
    private let jupiterOutgoing: SIMD3<Double>
    private let saturnOutgoing: SIMD3<Double>
    private let endpoint: SIMD3<Double>
    private let provider: any CelestialStateProviding
    private let timeline = MissionTimeline.forMission(.voyager1)

    init(snapshot: UniverseSceneSnapshot, provider: any CelestialStateProviding) throws {
        guard let earth = snapshot.planet(named: "Earth"),
              let jupiter = snapshot.planet(named: "Jupiter"),
              let saturn = snapshot.planet(named: "Saturn"),
              earth.surfaceRadius > 0, jupiter.surfaceRadius > 0, saturn.framingRadius > 0 else {
            throw TransferFailure.invalidGeometry
        }
        self.earth = earth
        jupiterRadius = jupiter.surfaceRadius
        // Include Saturn's rings when designing clearance and camera framing.
        saturnRadius = saturn.framingRadius
        self.provider = provider
        let timeline = MissionTimeline.forMission(.voyager1)
        let surface = SurfaceCoordinateMath.localUnitVector(
            for: SurfaceCoordinate(latitudeDegrees: 28.583, longitudeDegrees: -80.583))
        let radial = earth.visualRotationMatrix * SIMD4(surface, 0)
        launchDirection = normalize(SIMD3<Double>(Double(radial.x), Double(radial.y), Double(radial.z)))
        let reference = abs(launchDirection.y) < 0.95 ? SIMD3<Double>(0, 1, 0) : SIMD3<Double>(1, 0, 0)
        launchHeading = normalize(cross(reference, launchDirection))
        let jupiterPosition = try provider.state(for: .jupiter, at: timeline.epoch(at: 30)).scenePosition
        let saturnPosition = try provider.state(for: .saturn, at: timeline.epoch(at: 52)).scenePosition
        jupiterIncoming = normalize(jupiterPosition - earth.preciseWorldPosition)
        jupiterOutgoing = normalize(saturnPosition - jupiterPosition)
        // Illustrative endpoint, not spacecraft telemetry or a spherical heliopause model.
        let direction = normalize(normalize(saturnPosition) + SIMD3<Double>(0, 0.8, 0))
        endpoint = direction * 122 * 149_597_870.7 * OrbitalElements.sceneUnitsPerKm
        saturnOutgoing = normalize(endpoint - saturnPosition)
    }

    func body(_ body: CelestialBodyID, time: Double) throws -> SIMD3<Double> {
        try provider.state(for: body, at: timeline.epoch(at: time)).scenePosition
    }

    func position(time: Double) throws -> SIMD3<Double> {
        switch time {
        case ..<15: return launch(time: time)
        case ..<24:
            return try cruise(time: time, range: 15...24,
                              from: Boundary(position: launch(time: 15)),
                              to: encounterBoundary(time: 24, body: .jupiter))
        case ...36: return try encounter(time: time, body: .jupiter)
        case ..<46:
            return try cruise(time: time, range: 36...46,
                              from: encounterBoundary(time: 36, body: .jupiter),
                              to: encounterBoundary(time: 46, body: .saturn))
        case ...58: return try encounter(time: time, body: .saturn)
        default:
            return try cruise(time: min(time, 82), range: 58...82,
                              from: encounterBoundary(time: 58, body: .saturn), to: Boundary(position: endpoint))
        }
    }

    private func launch(time: Double) -> SIMD3<Double> {
        let unit = min(1, max(0, time / 15))
        // Smootherstep starts and ends with zero velocity AND zero acceleration.
        let eased = unit * unit * unit * (10 - 15 * unit + 6 * unit * unit)
        let radius = Double(earth.surfaceRadius)
        return earth.preciseWorldPosition + launchDirection * radius * (1.55 + 5 * eased)
            + launchHeading * radius * 2 * eased
    }

    private func encounter(time: Double, body bodyID: CelestialBodyID) throws -> SIMD3<Double> {
        let center = bodyID == .jupiter ? 30.0 : 52.0
        let radius = Double(bodyID == .jupiter ? jupiterRadius : saturnRadius)
        let incoming = bodyID == .jupiter ? jupiterIncoming : jupiterOutgoing
        let outgoing = bodyID == .jupiter ? jupiterOutgoing : saturnOutgoing
        let sum = incoming + outgoing
        let horizontal = SIMD3<Double>(sum.x, 0, sum.z)
        let middleDirection = length(horizontal) > 0.001 ? normalize(horizontal) : SIMD3<Double>(1, 0, 0)
        let clearance = SIMD3<Double>(0, radius * 3, 0)
        // Align approach/departure with the adjacent cruise legs instead of imposing
        // an unrelated orbital tangent. Spread the bend across the full 12-second flyby.
        let span = radius * 60
        let middle = Boundary(position: clearance, velocity: middleDirection * span / 6)
        let offset: SIMD3<Double>
        if time <= center {
            offset = Self.interpolate(from: Boundary(position: clearance - incoming * span,
                                                      velocity: incoming * span / 6),
                                      to: middle, duration: 6, fraction: (time - center + 6) / 6)
        } else {
            offset = Self.interpolate(from: middle,
                                      to: Boundary(position: clearance + outgoing * span,
                                                   velocity: outgoing * span / 6),
                                      duration: 6, fraction: (time - center) / 6)
        }
        return try body(bodyID, time: time) + offset
    }

    private func encounterBoundary(time: Double, body: CelestialBodyID) throws -> Boundary {
        // One-sided derivatives stay inside the encounter's calendar-speed interval.
        // Crossing into years/second here would introduce a false acceleration kick.
        let start = body == .jupiter ? 24.0 : 46.0
        let step = time == start ? 0.01 : -0.01
        let position = try encounter(time: time, body: body)
        let next = try encounter(time: time + step, body: body)
        let after = try encounter(time: time + step * 2, body: body)
        return Boundary(position: position, velocity: (-3 * position + 4 * next - after) / (2 * step),
                        acceleration: (position - 2 * next + after) / (step * step))
    }

    private func cruise(time: Double, range: ClosedRange<Double>,
                        from: Boundary, to endpoint: Boundary) -> SIMD3<Double> {
        let duration = range.upperBound - range.lowerBound
        return Self.interpolate(from: from, to: endpoint,
                                duration: duration, fraction: (time - range.lowerBound) / duration)
    }

    static func interpolate(from start: Boundary, to end: Boundary,
                            duration: Double, fraction: Double) -> SIMD3<Double> {
        let unit = min(1, max(0, fraction))
        let squared = unit * unit
        let cubed = squared * unit
        let fourth = cubed * unit
        let fifth = fourth * unit
        let position = start.position * (1 - 10 * cubed + 15 * fourth - 6 * fifth)
            + end.position * (10 * cubed - 15 * fourth + 6 * fifth)
        let velocity = start.velocity * duration * (unit - 6 * cubed + 8 * fourth - 3 * fifth)
            + end.velocity * duration * (-4 * cubed + 7 * fourth - 3 * fifth)
        let acceleration = start.acceleration * duration * duration * (squared - 3 * cubed + 3 * fourth - fifth) / 2
            + end.acceleration * duration * duration * (cubed - 2 * fourth + fifth) / 2
        return position + velocity + acceleration
    }
}
