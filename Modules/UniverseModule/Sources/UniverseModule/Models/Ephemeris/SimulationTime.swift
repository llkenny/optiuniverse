import Foundation

/// Ephemeris epochs are SI seconds since 2000-01-01 12:00 TDB, not UTC.
enum SimulationTime {
    static let utcJ2000 = Date(timeIntervalSince1970: 946_728_000)
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
        let atomicOffset = leaps.last { utc >= $0.0 }?.1 ?? 10
        let tt = date.timeIntervalSince(utcJ2000) + atomicOffset + 32.184
        return tt + tdbMinusTT(tt)
    }

    static func date(forTDBSeconds seconds: Double) -> Date {
        var date = utcJ2000.addingTimeInterval(seconds - 69.184)
        for _ in 0..<3 {
            date = date.addingTimeInterval(seconds - tdbSeconds(for: date))
        }
        return date
    }

    /// NAIF LSK DELTET model; its sub-millisecond residual is below our vector budget.
    private static func tdbMinusTT(_ tt: Double) -> Double {
        let mean = 6.239996 + 1.99096871e-7 * tt
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
