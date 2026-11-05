import simd

enum EphemerisOrbitPath {
    /// Sample one period when covered, otherwise expose an open archive-covered arc.
    /// Clamp each epoch to avoid sub-microsecond rounding outside a coverage boundary.
    static func points(for body: CelestialBodyID, period: Double, at epoch: Double,
                       provider: any CelestialStateProviding,
                       origin: SIMD3<Double> = .zero) throws -> [SIMD3<Double>] {
        try samples(for: body, period: period, at: epoch, provider: provider)
            .map { origin + $0.position }
    }

    /// Parent-relative samples remove the parent's motion at each sampled epoch, rather
    /// than mistaking a moon's heliocentric trajectory for its orbit around its planet.
    static func samples(for body: CelestialBodyID, relativeTo parent: CelestialBodyID? = nil,
                        period: Double, at epoch: Double,
                        provider: any CelestialStateProviding) throws -> [CelestialOrbitSnapshot.Sample] {
        guard period.isFinite, period > 0, epoch.isFinite else { throw CelestialStateError.invalidData }
        let coverage = provider.coverage
        let span = min(period, coverage.map { $0.upperBound - $0.lowerBound } ?? period)
        guard span.isFinite, span > 0 else { throw CelestialStateError.invalidData }
        var start = epoch - span / 2
        if let coverage { start = min(max(start, coverage.lowerBound), coverage.upperBound - span) }
        return try (0...256).map { index in
            let sampledEpoch = index == 256 ? start + span : start + Double(index) / 256 * span
            let date = coverage.map { min(max(sampledEpoch, $0.lowerBound), $0.upperBound) } ?? sampledEpoch
            let position = try provider.state(for: body, at: date).scenePosition
            let parentPosition = try parent.map { try provider.state(for: $0, at: date).scenePosition } ?? .zero
            let relativePosition = position - parentPosition
            guard relativePosition.x.isFinite, relativePosition.y.isFinite, relativePosition.z.isFinite else {
                throw CelestialStateError.invalidData
            }
            return CelestialOrbitSnapshot.Sample(epoch: date, position: relativePosition)
        }
    }
}
