import Foundation
import simd
import Testing
@testable import UniverseModule

@Test func vostokTimelineAndPhasesShareHistoricalCues() throws {
    let timeline = MissionTimeline.forMission(.vostok1)
    let profile = try makeVostokProfile()
    let expected: [((Double, String), MissionNavigationStatus.Phase)] = [
        ((0, "06:07"), .launch), ((4, "06:09"), .boosterSeparation), ((5.5, "06:10"), .fairingSeparation),
        ((8, "06:12"), .separation), ((13, "06:18"), .orbit), ((35, "07:25"), .deorbit),
        ((43, "07:36"), .reentry), ((49, "07:42"), .ejection), ((54, "07:48"), .capsuleLanded),
        ((57, "07:55"), .vostokLanded), ((60, "07:55"), .vostokLanded)
    ]
    #expect(timeline.duration == 60)
    #expect(timeline.anchors.map(\.playbackTime) == expected.map { $0.0.0 })
    for ((time, clock), phase) in expected {
        let date = try #require(ISO8601DateFormatter().date(from: "1961-04-12T\(clock):00Z"))
        #expect(abs(SimulationTime.date(forTDBSeconds: timeline.epoch(at: time)).timeIntervalSince(date)) < 0.001)
        #expect(profile.status(time: time).phase == phase)
    }
    #expect(profile.sample(time: 36).retrofire > 0.5)
    #expect(profile.sample(time: 45).entryGlow > 0.5)
    #expect(profile.sample(time: 48.99).pilot == nil)
    #expect(profile.sample(time: 49).pilot != nil)
    #expect(profile.status(time: 57).epilogueText != nil)
}

@Test func vostokRouteFollowsOneProgradeCircuitAndStaysAboveEarth() throws {
    let profile = try makeVostokProfile()
    let route = profile.makeRoute()
    #expect(route.hasMissionVehicles)
    #expect(route.mission == .vostok1)
    #expect(route.originName == "Earth" && route.destinationName == "Earth")
    #expect(route.totalDistance.isFinite && route.totalDistance > 0)
    let points = route.precisePoints.map { $0 - profile.preciseCenter }
    var orbitArc = 0.0
    for (index, point) in points.enumerated() {
        #expect(length(point) >= Double(profile.radius) * 0.99999)
        let time = Double(index) / 8
        let flight = profile.sample(time: time)
        #expect(abs(length(flight.capsule.orientation.vector) - 1) < 0.0001)
        #expect(flight.capsule.precisePosition == profile.precisePosition(time: time))
        if let pilot = flight.pilot {
            #expect(length(pilot.precisePosition - profile.preciseCenter) >= Double(profile.radius) * 0.99999)
        }
        guard index > 0 else { continue }
        let previous = points[index - 1]
        #expect(distance(previous, point) < Double(profile.radius) * 0.12)
        if (13.125...35).contains(time) {
            let normal = SIMD3<Double>(profile.normal)
            let step = cross(normalize(previous), normalize(point))
            orbitArc += atan2(dot(normal, step), dot(normalize(previous), normalize(point)))
            #expect(abs(dot(normalize(point), normal)) < 0.00001)
        }
    }
    #expect(abs(orbitArc - 67 / 89.34 * 2 * .pi) < 0.001)
    let translated = profile.translatedPrecisely(to: profile.preciseCenter + SIMD3(90, -40, 30))
    #expect(translated.normal == profile.normal)
    #expect(distance(translated.precisePosition(time: 28) - profile.precisePosition(time: 28),
                     SIMD3(90, -40, 30)) < 1e-12)
}

@Test func vostokTakeoffAndSeparateTouchdownsMatchDatedEarth() throws {
    let profile = try makeVostokProfile()
    let timeline = MissionTimeline.forMission(.vostok1)
    let archive = try EphemerisArchive.bundled.get()
    let launch = try archive.state(for: .earth, at: timeline.departureEpoch)
    let arrival = try archive.state(for: .earth, at: timeline.arrivalEpoch)
    let launchSite = SurfaceCoordinateMath.surfaceOffset(on: earthSnapshot(launch), at: VostokRouteProfile.launchSite)
    #expect(distance(normalize(profile.precisePosition(time: 0) - profile.preciseCenter),
                     SIMD3<Double>(normalize(launchSite))) < 1e-6)

    let capsuleTouchdown = profile.sample(time: 54)
    let pilotAtCapsuleTouchdown = try #require(capsuleTouchdown.pilot)
    #expect(length(pilotAtCapsuleTouchdown.precisePosition - profile.preciseCenter) > Double(profile.radius))
    let capsuleEpoch = timeline.epoch(at: 54)
    let earthAtCapsuleTouchdown = try archive.state(for: .earth, at: capsuleEpoch)
    let capsuleSite = SurfaceCoordinateMath.surfaceOffset(on: earthSnapshot(earthAtCapsuleTouchdown),
                                                         at: VostokRouteProfile.capsuleSite)
    #expect(distance(capsuleTouchdown.capsule.precisePosition - profile.preciseCenter,
                     SIMD3<Double>(capsuleSite)) < Double(profile.radius) * 0.00002)

    let landed = profile.sample(time: 57)
    let pilot = try #require(landed.pilot)
    let pilotSite = SurfaceCoordinateMath.surfaceOffset(on: earthSnapshot(arrival), at: VostokRouteProfile.pilotSite)
    #expect(distance(pilot.precisePosition - profile.preciseCenter, SIMD3<Double>(pilotSite)) < 1e-8)
    #expect(pilot.precisePosition != landed.capsule.precisePosition)
    #expect(profile.sample(time: 60) == landed)
}

private func earthSnapshot(_ state: CelestialBodyState) -> CelestialBodySnapshot {
    CelestialBodySnapshot(planetName: "Earth", baseModelMatrix: state.sceneOrientation,
                          normalizedScale: 0.006378, framingRadius: 0.006378, surfaceRadius: 0.006378,
                          worldPosition: SIMD3<Float>(state.scenePosition), preciseWorldPosition: state.scenePosition)
}

private func makeVostokProfile() throws -> VostokRouteProfile {
    let timeline = MissionTimeline.forMission(.vostok1)
    let archive = try EphemerisArchive.bundled.get()
    let launch = try archive.state(for: .earth, at: timeline.departureEpoch)
    let landing = try archive.state(for: .earth, at: timeline.arrivalEpoch)
    return try #require(VostokRouteProfile(earth: earthSnapshot(launch), arrivalOrientation: landing.sceneOrientation))
}
