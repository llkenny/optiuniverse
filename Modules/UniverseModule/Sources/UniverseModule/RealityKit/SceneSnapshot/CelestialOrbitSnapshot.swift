import simd

struct CelestialOrbitSnapshot: Equatable, Sendable {
    struct Sample: Equatable, Sendable {
        let epoch: Double
        let position: SIMD3<Double>
    }

    let body: CelestialBodyID
    let parent: CelestialBodyID?
    let samples: [Sample]

    /// Insert the exact current position between its dated neighbours. Cached guide
    /// samples can then be reused without letting a small, moving body leave its line.
    func renderPoints(in scene: UniverseSceneSnapshot, relativeTo origin: SIMD3<Double>) -> [SIMD3<Float>] {
        guard let packet = scene.planet(named: body.rawValue), samples.count >= 2,
              let first = samples.first, let last = samples.last,
              (first.epoch...last.epoch).contains(scene.simulationTime) else { return [] }
        let parentPosition: SIMD3<Double>
        if let parent {
            guard let parentPacket = scene.planet(named: parent.rawValue) else { return [] }
            parentPosition = parentPacket.preciseWorldPosition
        } else {
            parentPosition = .zero
        }

        var points: [SIMD3<Float>] = []
        points.reserveCapacity(samples.count + 1)
        var insertedCurrentPosition = false
        for sample in samples {
            if !insertedCurrentPosition, sample.epoch >= scene.simulationTime {
                points.append(EphemerisCoordinates.renderPosition(packet.preciseWorldPosition, relativeTo: origin))
                insertedCurrentPosition = true
            }
            if sample.epoch != scene.simulationTime {
                points.append(SIMD3<Float>((parentPosition - origin) + sample.position))
            }
        }
        return points
    }
}

/// Geometry is refreshed in simulation time, not wall time, including backward date jumps.
struct CelestialOrbitCache {
    private struct Entry {
        let epoch: Double
        let interval: Double
        let orbit: CelestialOrbitSnapshot?
    }

    private var entries: [CelestialBodyID: Entry] = [:]

    mutating func snapshots(for planets: [Planet], at epoch: Double,
                            provider: any CelestialStateProviding) -> [CelestialOrbitSnapshot] {
        planets.compactMap { planet in
            guard let body = CelestialBodyID(rawValue: planet.name), body != .sun,
                  let orbit = planet.orbit, orbit.isValid else { return nil }
            let parent = planet.parentName.flatMap(CelestialBodyID.init(rawValue:))
            guard planet.parentName == nil || parent != nil else { return nil }
            if let cached = entries[body], abs(epoch - cached.epoch) < cached.interval {
                return cached.orbit
            }
            let span = min(orbit.periodSeconds, provider.coverage.map { $0.upperBound - $0.lowerBound }
                           ?? orbit.periodSeconds)
            let samples = try? EphemerisOrbitPath.samples(for: body, relativeTo: parent,
                                                          period: orbit.periodSeconds, at: epoch, provider: provider)
            let snapshot = samples.map { CelestialOrbitSnapshot(body: body, parent: parent, samples: $0) }
            entries[body] = Entry(epoch: epoch, interval: span / 256, orbit: snapshot)
            return snapshot
        }
    }
}
