import simd

enum EphemerisOrbitPath {
    /// Sample one period when covered, otherwise expose an open archive-covered arc.
    /// Clamp each epoch to avoid sub-microsecond rounding outside a coverage boundary.
    static func points(for body: CelestialBodyID, period: Double, at epoch: Double,
                       provider: any CelestialStateProviding,
                       origin: SIMD3<Double> = .zero) throws -> [SIMD3<Double>] {
        let coverage = provider.coverage
        let span = min(period, coverage.map { $0.upperBound - $0.lowerBound } ?? period)
        var start = epoch - span / 2
        if let coverage { start = min(max(start, coverage.lowerBound), coverage.upperBound - span) }
        return try (0...256).map { index in
            let sampledEpoch = index == 256 ? start + span : start + Double(index) / 256 * span
            let date = coverage.map { min(max(sampledEpoch, $0.lowerBound), $0.upperBound) } ?? sampledEpoch
            return origin + (try provider.state(for: body, at: date).scenePosition)
        }
    }
}
