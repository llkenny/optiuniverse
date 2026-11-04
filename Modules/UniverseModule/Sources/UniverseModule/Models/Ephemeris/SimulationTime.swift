import Foundation

/// Ephemeris epochs are SI seconds since 2000-01-01 12:00 TDB, not UTC.
enum SimulationTime {
    static let utcJ2000 = Date(timeIntervalSince1970: 946_728_000)
    static let calendarStartUTC = Date(timeIntervalSince1970: -283_996_800)
    static let calendarEndUTC = Date(timeIntervalSince1970: 4_133_980_800)

    // IERS TAI−UTC table, in MJD. Before 1972 the offset also drifted within each interval.
    private struct HistoricalOffset {
        let start: Double
        let offset: Double
        let reference: Double
        let drift: Double

        init(_ start: Double, _ offset: Double, _ reference: Double, _ drift: Double) {
            self.start = start
            self.offset = offset
            self.reference = reference
            self.drift = drift
        }
    }

    private static let historicalOffsets: [HistoricalOffset] = [
        .init(37_300, 1.422818, 37_300, 0.001296), .init(37_512, 1.372818, 37_300, 0.001296),
        .init(37_665, 1.845858, 37_665, 0.0011232), .init(38_334, 1.945858, 37_665, 0.0011232),
        .init(38_395, 3.240130, 38_761, 0.001296), .init(38_486, 3.340130, 38_761, 0.001296),
        .init(38_639, 3.440130, 38_761, 0.001296), .init(38_761, 3.540130, 38_761, 0.001296),
        .init(38_820, 3.640130, 38_761, 0.001296), .init(38_942, 3.740130, 38_761, 0.001296),
        .init(39_004, 3.840130, 38_761, 0.001296), .init(39_126, 4.313170, 39_126, 0.002592),
        .init(39_887, 4.213170, 39_126, 0.002592)
    ]

    // NAIF naif0012.tls. Future UTC uses the last announced leap second.
    private static let leaps: [(Double, Double)] = [
        (63_072_000, 10), (78_796_800, 11), (94_694_400, 12), (126_230_400, 13),
        (157_766_400, 14), (189_302_400, 15), (220_924_800, 16), (252_460_800, 17),
        (283_996_800, 18), (315_532_800, 19), (362_793_600, 20), (394_329_600, 21),
        (425_865_600, 22), (489_024_000, 23), (567_993_600, 24), (631_152_000, 25),
        (662_688_000, 26), (709_948_800, 27), (741_484_800, 28), (773_020_800, 29),
        (820_454_400, 30), (867_715_200, 31), (915_148_800, 32), (1_136_073_600, 33),
        (1_230_768_000, 34), (1_341_100_800, 35), (1_435_708_800, 36), (1_483_228_800, 37)
    ]

    static func tdbSeconds(for date: Date) -> Double {
        let utc = date.timeIntervalSince1970
        let atomicOffset: Double
        if let leap = leaps.last(where: { utc >= $0.0 }) {
            atomicOffset = leap.1
        } else {
            let mjd = 40_587 + utc / 86_400
            let era = historicalOffsets.last { mjd >= $0.start } ?? historicalOffsets[0]
            atomicOffset = era.offset + (mjd - era.reference) * era.drift
        }
        let terrestrialTime = date.timeIntervalSince(utcJ2000) + atomicOffset + 32.184
        return terrestrialTime + tdbMinusTT(terrestrialTime)
    }

    static func date(forTDBSeconds seconds: Double) -> Date {
        var date = utcJ2000.addingTimeInterval(seconds - 69.184)
        for _ in 0..<3 {
            date = date.addingTimeInterval(seconds - tdbSeconds(for: date))
        }
        return date
    }

    /// NAIF LSK DELTET model; its sub-millisecond residual is below our vector budget.
    private static func tdbMinusTT(_ terrestrialTime: Double) -> Double {
        let mean = 6.239996 + 1.99096871e-7 * terrestrialTime
        return 0.001657 * sin(mean + 0.01671 * sin(mean))
    }
}

public enum SimulationMode: String, Equatable, Sendable {
    case live
    case transferPreview
    case missionReplay
}

public struct SimulationSnapshot: Equatable, Sendable {
    public let dateUTC: Date
    public let mode: SimulationMode
    public let error: CelestialStateError?

    public init(dateUTC: Date, mode: SimulationMode = .live, error: CelestialStateError? = nil) {
        self.dateUTC = dateUTC
        self.mode = mode
        self.error = error
    }
}
