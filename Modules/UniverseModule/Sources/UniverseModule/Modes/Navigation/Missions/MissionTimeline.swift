import Foundation

/// Maps active cinematic seconds to dated body states. Spacecraft geometry remains illustrative.
struct MissionTimeline: Sendable, Equatable {
    struct Anchor: Sendable, Equatable {
        let playbackTime: TimeInterval
        let epoch: Double
    }

    let duration: TimeInterval
    let anchors: [Anchor]

    var departureEpoch: Double { anchors[0].epoch }
    var arrivalEpoch: Double { anchors[anchors.count - 1].epoch }

    func epoch(at elapsedTime: TimeInterval) -> Double {
        let time = elapsedTime.isFinite ? min(duration, max(0, elapsedTime)) : 0
        guard let upper = anchors.firstIndex(where: { $0.playbackTime > time }) else { return arrivalEpoch }
        guard upper > 0 else { return departureEpoch }
        let left = anchors[upper - 1]
        let right = anchors[upper]
        let fraction = (time - left.playbackTime) / (right.playbackTime - left.playbackTime)
        return left.epoch + (right.epoch - left.epoch) * fraction
    }

    func validateEphemeris(_ provider: any CelestialStateProviding) throws {
        if let coverage = provider.coverage,
           !coverage.contains(departureEpoch) || !coverage.contains(arrivalEpoch) {
            throw CelestialStateError.outsideCoverage
        }
        for anchor in anchors {
            for body in CelestialBodyID.allCases {
                _ = try provider.state(for: body, at: anchor.epoch)
            }
        }
    }

    static func forMission(_ mission: MissionFlightPlan) -> Self {
        switch mission {
        case .artemisII: artemisII
        case .starshipFlight14: starshipFlight14
        case .crew13: crew13
        case .voyager1: voyager1
        }
    }

    // NASA recap: https://www.youtube.com/watch?v=_eeZQw9PBc0
    // Actual closest approach (19:00 EDT, not the planned 19:02):
    // https://www.nasa.gov/blogs/missions/2026/04/06/artemis-ii-flight-day-6-lunar-flyby-updates/
    // Splashdown reference:
    // https://ntrs.nasa.gov/api/citations/20260004348/downloads/Final%20-%20JANNAF%202026%20Presentation.pdf
    // UTC anchors have minute precision; the playback mapping includes the existing close-up easing.
    private static let artemisII = Self(duration: 16, anchors: [
        Anchor(playbackTime: 0, epoch: epochUTC("2026-04-01T22:35:00Z")),
        Anchor(playbackTime: ArtemisRouteProfile.playbackTime(
            forRouteProgress: ArtemisRouteProfile.lunarEncounterProgress, estimatedDuration: 16),
               epoch: epochUTC("2026-04-06T23:00:00Z")),
        Anchor(playbackTime: 16, epoch: epochUTC("2026-04-11T00:07:00Z"))
    ])

    // Post-flight report, NOT the superseded planned ten-hour timeline:
    // space.com/space-exploration/launches-spacecraft/spacex-starship-megarocket-flight-14-orbital-launch-success
    // Launch ~12:48 UTC; deployment ~T+34...64 min, entry ~T+2h40m, splashdown ~T+3h08m.
    // All these historical anchors are approximate, to minute precision.
    private static let starshipFlight14: Self = {
        let start = epochUTC("2026-09-28T12:48:00Z")
        return Self(duration: 60, anchors: [
            Anchor(playbackTime: 0, epoch: start),
            Anchor(playbackTime: 19, epoch: start + 34 * 60),
            Anchor(playbackTime: 28.4, epoch: start + 64 * 60),
            Anchor(playbackTime: 46, epoch: start + 160 * 60),
            Anchor(playbackTime: 60, epoch: start + 188 * 60)
        ])
    }()

    // NASA's actual docking report gives 19:05 EDT and 7h55m from launch (minute precision):
    // https://www.nasa.gov/blogs/spacestation/2026/10/01/dragon-docks-bringing-spacex-crew-13-to-station/
    // The final cinematic docked hold keeps the docking epoch while presentation animation continues.
    private static let crew13 = Self(duration: 60, anchors: [
        Anchor(playbackTime: 0, epoch: epochUTC("2026-10-01T15:10:00Z")),
        Anchor(playbackTime: 58, epoch: epochUTC("2026-10-01T23:05:00Z")),
        Anchor(playbackTime: 60, epoch: epochUTC("2026-10-01T23:05:00Z"))
    ])

    // NASA: science.nasa.gov/mission/voyager/voyager-1/
    // Flyby close-ups span four historical days; launch and epilogue hold their date.
    // The heliopause crossing is known to day precision, represented at midnight UTC.
    private static let voyager1: Self = {
        let launch = epochUTC("1977-09-05T12:56:01Z")
        let jupiter = epochUTC("1979-03-05T12:05:00Z")
        let saturn = epochUTC("1980-11-12T23:46:00Z")
        let crossing = epochUTC("2012-08-25T00:00:00Z")
        let twoDays = 2.0 * 86_400
        return Self(duration: 90, anchors: [
            Anchor(playbackTime: 0, epoch: launch), Anchor(playbackTime: 15, epoch: launch),
            Anchor(playbackTime: 24, epoch: jupiter - twoDays),
            Anchor(playbackTime: 30, epoch: jupiter), Anchor(playbackTime: 36, epoch: jupiter + twoDays),
            Anchor(playbackTime: 46, epoch: saturn - twoDays),
            Anchor(playbackTime: 52, epoch: saturn), Anchor(playbackTime: 58, epoch: saturn + twoDays),
            Anchor(playbackTime: 82, epoch: crossing), Anchor(playbackTime: 90, epoch: crossing)
        ])
    }()

    private static func epochUTC(_ value: String) -> Double {
        // Fixed, bundled ISO-8601 UTC literals; independent of device calendar and timezone.
        guard let date = ISO8601DateFormatter().date(from: value) else { preconditionFailure("Invalid mission date") }
        return SimulationTime.tdbSeconds(for: date)
    }
}

/// One launch identity, including restarts of the same mission. Pending launches hold their first epoch.
struct MissionReplay: Sendable, Equatable {
    let id: UUID
    let mission: MissionFlightPlan
    var isPreparing = false

    var timeline: MissionTimeline { .forMission(mission) }
}
