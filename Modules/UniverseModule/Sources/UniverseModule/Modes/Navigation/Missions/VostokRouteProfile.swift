import Foundation
import simd

enum VostokFlightCue: TimeInterval {
    case launch = 0
    case boosters = 4
    case fairing = 5.5
    case core = 8
    case upperStageBurn = 9
    case orbit = 13
    case retrofire = 35
    case entry = 43
    case ejection = 49
    case parachutes = 50
    case capsuleLanded = 54
    case pilotLanded = 57
    case end = 60
}

struct VostokFlightState: Sendable, Equatable {
    let capsule: MissionVehiclePose
    let pilot: MissionVehiclePose?
    let surfaceUp: SIMD3<Float>
    let retrofire: Float
    let entryGlow: Float
}

struct VostokRouteProfile: Sendable, Equatable {
    static let launchSite = SurfaceCoordinate(latitudeDegrees: 45.9203, longitudeDegrees: 63.3422)
    static let pilotSite = SurfaceCoordinate(latitudeDegrees: 51.2707, longitudeDegrees: 45.9973)
    // The capsule came down slightly closer to the Volga. The cinematic separation
    // is widened during descent so both parachutes can be seen.
    static let capsuleSite = SurfaceCoordinate(latitudeDegrees: 51.2707, longitudeDegrees: 46.0173)
    private static let entrySite = SurfaceCoordinate(latitudeDegrees: 27, longitudeDegrees: 30)
    private static let ejectionSite = SurfaceCoordinate(latitudeDegrees: 50.4, longitudeDegrees: 44.9)
    private static let timeline = MissionTimeline.forMission(.vostok1)
    private static let orbitalPeriod = 89.34 * 60
    private static let insertionAngle = 28.0 * Double.pi / 180

    private(set) var preciseCenter: SIMD3<Double>
    let radius: Float
    let normal: SIMD3<Float>
    private let launchRadial: SIMD3<Float>
    private let heading: SIMD3<Float>
    private let launchRotation: simd_quatf
    private let arrivalRotation: simd_quatf

    var vehicleScale: Float { radius * 0.034 }

    init?(earth: CelestialBodySnapshot, arrivalOrientation: float4x4) {
        guard earth.surfaceRadius.isFinite, earth.surfaceRadius > 0,
              simd_length(earth.preciseWorldPosition).isFinite else { return nil }
        radius = earth.surfaceRadius
        preciseCenter = earth.preciseWorldPosition
        launchRotation = simd_quatf(earth.visualRotationMatrix)
        arrivalRotation = simd_quatf(arrivalOrientation)
        guard simd_length(launchRotation.vector).isFinite,
              simd_length(arrivalRotation.vector).isFinite else { return nil }

        let localRadial = SurfaceCoordinateMath.localUnitVector(for: Self.launchSite)
        let longitude = Self.launchSite.longitudeDegrees * .pi / 180
        let east = SIMD3<Float>(-sin(longitude), 0, -cos(longitude))
        let north = cross(localRadial, east)
        // For a prograde northeast launch, sin(azimuth) = cos(inclination) / cos(latitude).
        let inclination: Float = 64.95 * .pi / 180
        let eastward = cos(inclination) / cos(Self.launchSite.latitudeDegrees * .pi / 180)
        launchRadial = normalize(launchRotation.act(localRadial))
        heading = normalize(launchRotation.act(east * eastward + north * sqrt(1 - eastward * eastward)))
        normal = normalize(cross(launchRadial, heading))
    }

    func translatedPrecisely(to center: SIMD3<Double>) -> Self {
        var result = self
        result.preciseCenter = center
        return result
    }

    func makeRoute() -> NavigationRoute {
        let duration = Self.timeline.duration
        let points = (0...480).map { precisePosition(time: duration * Double($0) / 480) }
        let distances = RoutePathBuilder.makeCumulativeDistances(precisePoints: points)
        return NavigationRoute(originName: "Earth", destinationName: "Earth", points: points.map { SIMD3<Float>($0) },
                               cumulativeDistances: distances, totalDistance: distances.last ?? 0,
                               estimatedDuration: duration, overviewPaddingRadius: radius * 1.4,
                               overviewCenter: SIMD3<Float>(preciseCenter), precisePoints: points,
                               preciseOverviewCenter: preciseCenter, mission: .vostok1, vostokProfile: self)
    }

    func precisePosition(time: TimeInterval) -> SIMD3<Double> {
        preciseCenter + SIMD3<Double>(capsuleOffset(at: Self.clamped(time)))
    }

    func sample(time: TimeInterval) -> VostokFlightState {
        let time = Self.clamped(time)
        let capsuleOffset = capsuleOffset(at: time)
        let radial = normalize(capsuleOffset)
        let tangent = normalize(cross(normal, radial))
        let pitch = fraction(time, from: .launch, to: .core)
        let ascentAxis = normalize(radial * (1 - pitch) + tangent * pitch)
        let descent = fraction(time, from: .retrofire, to: .ejection)
        let entryAxis = normalize(tangent * (1 - descent) + radial * descent)
        let brake = pulse(time, from: .retrofire, length: 1.6)
        let brakeAttitude = Crew13RouteProfile.smooth(Float((time - 33) / 2))
            * (1 - Crew13RouteProfile.smooth(Float((time - 37) / 4)))
        let turn = simd_quatf(angle: .pi * brakeAttitude, axis: radial)
        let axis = time < VostokFlightCue.orbit.rawValue ? ascentAxis : entryAxis
        // Rotate the complete attitude frame. Rebuilding it mid-turn would
        // make the turned forward axis briefly parallel to the orbit normal.
        let capsule = pose(offset: capsuleOffset, axis: axis, turn: turn)
        var pilot: MissionVehiclePose?
        if time >= VostokFlightCue.ejection.rawValue {
            let offset = descentOffset(time: time, landing: Self.pilotSite, touchdown: .pilotLanded, side: -1)
            pilot = pose(offset: offset, axis: normalize(offset))
        }
        return VostokFlightState(capsule: capsule, pilot: pilot, surfaceUp: radial,
                                 retrofire: brake, entryGlow: pulse(time, from: .entry, length: 5.5))
    }

    private static let phases: [(VostokFlightCue, MissionNavigationStatus.Phase)] = [
        (.launch, .launch), (.boosters, .boosterSeparation), (.fairing, .fairingSeparation),
        (.core, .separation), (.upperStageBurn, .secondStageBurn), (.orbit, .orbit),
        (.retrofire, .deorbit), (.entry, .reentry), (.ejection, .ejection),
        (.parachutes, .parachuteDescent), (.capsuleLanded, .capsuleLanded), (.pilotLanded, .vostokLanded)
    ]

    func status(time: TimeInterval) -> MissionNavigationStatus {
        let time = Self.clamped(time)
        let phase = Self.phases.last { $0.0.rawValue <= time }?.1 ?? .launch
        let currentOrbit = time < VostokFlightCue.orbit.rawValue ? 0 : 1
        return MissionNavigationStatus(mission: .vostok1, phase: phase, currentOrbit: currentOrbit,
                                       totalOrbits: 1, deployedSatelliteCount: 0)
    }

    func vehicleSize(at time: TimeInterval) -> Float {
        vehicleScale * (1 - 0.86 * fraction(time, from: .entry, to: .pilotLanded))
    }

    private func capsuleOffset(at time: TimeInterval) -> SIMD3<Float> {
        switch time {
        case ..<VostokFlightCue.orbit.rawValue:
            let progress = Float(time / VostokFlightCue.orbit.rawValue)
            let angle = Self.insertionAngle * Double(progress * progress)
            let height = orbitHeight(angle: Self.insertionAngle)
            // Keep the tail of the enlarged launch stack above the pad at liftoff.
            let launchClearance = vehicleScale * 4.2
            return direction(angle: angle) * (radius + launchClearance + (height - launchClearance) * progress)
        case ..<VostokFlightCue.retrofire.rawValue:
            let angle = orbitalAngle(time: time)
            return direction(angle: angle) * (radius + orbitHeight(angle: angle))
        case ..<VostokFlightCue.entry.rawValue:
            let progress = fraction(time, from: .retrofire, to: .entry)
            let startAngle = orbitalAngle(time: VostokFlightCue.retrofire.rawValue)
            let continued = direction(angle: orbitalAngle(time: time))
            let radial = blend(continued, groundDirection(Self.entrySite, time: time), progress)
            return radial * (radius + mix(orbitHeight(angle: startAngle), radius * 0.16, progress))
        case ..<VostokFlightCue.ejection.rawValue:
            let progress = fraction(time, from: .entry, to: .ejection)
            let radial = blend(groundDirection(Self.entrySite, time: time),
                               groundDirection(Self.ejectionSite, time: time), progress)
            return radial * (radius + mix(radius * 0.16, ejectionHeight, progress))
        default:
            return descentOffset(time: time, landing: Self.capsuleSite, touchdown: .capsuleLanded, side: 1)
        }
    }

    private var ejectionHeight: Float { radius * 0.052 }

    private func descentOffset(time: TimeInterval, landing: SurfaceCoordinate,
                               touchdown: VostokFlightCue, side: Float) -> SIMD3<Float> {
        let progress = fraction(time, from: .ejection, to: touchdown)
        let start = groundDirection(Self.ejectionSite, time: time)
        let end = groundDirection(landing, time: time)
        let across = normalize(cross(end, arrivalRotation.act(SIMD3<Float>(0, 1, 0))))
        let spread = sin(progress * .pi) * 0.028 * side
        let radial = normalize(blend(start, end, progress) + across * spread)
        return radial * (radius + ejectionHeight * (1 - progress))
    }

    private func groundDirection(_ site: SurfaceCoordinate, time: TimeInterval) -> SIMD3<Float> {
        let elapsed = Self.timeline.epoch(at: time) - Self.timeline.departureEpoch
        let fraction = Float(elapsed / (Self.timeline.arrivalEpoch - Self.timeline.departureEpoch))
        // Over 108 minutes the IAU Earth rotation is effectively uniform.
        let rotation = simd_slerp(launchRotation, arrivalRotation, fraction)
        return normalize(rotation.act(SurfaceCoordinateMath.localUnitVector(for: site)))
    }

    private func orbitalAngle(time: TimeInterval) -> Double {
        let orbitalSeconds = Self.timeline.epoch(at: time) - Self.timeline.epoch(at: VostokFlightCue.orbit.rawValue)
        return Self.insertionAngle + orbitalSeconds / Self.orbitalPeriod * 2 * .pi
    }

    private func orbitHeight(angle: Double) -> Float {
        let perigee = 6_371.0 + 181
        let apogee = 6_371.0 + 327
        let eccentricity = (apogee - perigee) / (apogee + perigee)
        let distance = perigee * (1 + eccentricity) / (1 + eccentricity * cos(angle - Self.insertionAngle))
        return radius * Float((distance - 6_371) / 6_371) * 6
    }

    private func direction(angle: Double) -> SIMD3<Float> {
        launchRadial * Float(cos(angle)) + heading * Float(sin(angle))
    }

    private func pose(offset: SIMD3<Float>, axis: SIMD3<Float>,
                      turn: simd_quatf = simd_quatf(angle: 0, axis: SIMD3(0, 1, 0))) -> MissionVehiclePose {
        let right = normalize(cross(axis, normal))
        let orientation = simd_quatf(simd_float3x3(columns: (right, axis, cross(right, axis))))
        return MissionVehiclePose(position: .zero, orientation: simd_normalize(turn * orientation),
                                  precisePosition: preciseCenter + SIMD3<Double>(offset))
    }

    private func blend(_ from: SIMD3<Float>, _ destination: SIMD3<Float>, _ progress: Float) -> SIMD3<Float> {
        normalize(from * (1 - progress) + destination * progress)
    }

    private func mix(_ from: Float, _ destination: Float, _ progress: Float) -> Float {
        from + (destination - from) * progress
    }

    private func fraction(_ time: TimeInterval, from: VostokFlightCue, to destination: VostokFlightCue) -> Float {
        Crew13RouteProfile.smooth(Float((time - from.rawValue) / (destination.rawValue - from.rawValue)))
    }

    private func pulse(_ time: TimeInterval, from: VostokFlightCue, length: TimeInterval) -> Float {
        let progress = min(1, max(0, (time - from.rawValue) / length))
        return max(0, Float(sin(progress * .pi)))
    }

    private static func clamped(_ time: TimeInterval) -> TimeInterval {
        time.isFinite ? min(timeline.duration, max(0, time)) : 0
    }
}
