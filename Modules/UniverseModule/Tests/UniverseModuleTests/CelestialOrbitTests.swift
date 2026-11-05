import Foundation
import simd
import Synchronization
import Testing
@testable import UniverseModule

@Test func celestialOrbitCacheIncludesAllOrbitingBodiesAndReusesSamples() throws {
    let provider = CountingOrbitProvider()
    var cache = CelestialOrbitCache()
    let first = cache.snapshots(for: testPlanets, at: 0, provider: provider)
    let initialQueries = provider.queryCount.withLock { $0 }
    let reused = cache.snapshots(for: testPlanets, at: 1, provider: provider)

    #expect(Set(first.map(\.body)) == Set(CelestialBodyID.allCases.filter { $0 != .sun }))
    #expect(first.allSatisfy { $0.samples.count == 257 })
    #expect(first == reused)
    #expect(provider.queryCount.withLock { $0 } == initialQueries)

    let moonPeriod = try #require(testPlanets.first { $0.name == "Moon" }?.orbit?.periodSeconds)
    let refreshed = cache.snapshots(for: testPlanets, at: moonPeriod / 256, provider: provider)
    #expect(refreshed.first { $0.body == .moon } != first.first { $0.body == .moon })
    #expect(provider.queryCount.withLock { $0 } == initialQueries + 514)
    let backward = cache.snapshots(for: testPlanets, at: -moonPeriod, provider: provider)
    #expect(backward.first { $0.body == .moon } != refreshed.first { $0.body == .moon })
}

@Test func lunarOrbitRemovesEarthMotionAtEverySampleEpoch() throws {
    let provider = KeplerCelestialStateProvider(planets: testPlanets)
    let period = try #require(testPlanets.first { $0.name == "Moon" }?.orbit?.periodSeconds)
    let samples = try EphemerisOrbitPath.samples(for: .moon, relativeTo: .earth,
                                                period: period, at: 0, provider: provider)
    for sample in samples {
        let moon = try provider.state(for: .moon, at: sample.epoch).scenePosition
        let earth = try provider.state(for: .earth, at: sample.epoch).scenePosition
        #expect(simd_distance(sample.position, moon - earth) < 1e-12)
        #expect(simd_length(sample.position) < 0.5)
    }
}

@Test func orbitSamplesRespectArchiveBoundariesAndKeepOuterArcsOpen() throws {
    let archive = try EphemerisArchive.bundled.get()
    let coverage = try #require(archive.coverage)
    for body in [CelestialBodyID.mercury, .moon, .neptune, .pluto] {
        let period = try #require(testPlanets.first { $0.name == body.rawValue }?.orbit?.periodSeconds)
        for epoch in [coverage.lowerBound, coverage.upperBound] {
            let samples = try EphemerisOrbitPath.samples(for: body, period: period,
                                                        at: epoch, provider: archive)
            let first = try #require(samples.first)
            let last = try #require(samples.last)
            #expect(samples.allSatisfy { coverage.contains($0.epoch) })
            #expect(abs(last.epoch - first.epoch - min(period, coverage.upperBound - coverage.lowerBound)) < 1e-5)
            #expect((first.epoch...last.epoch).contains(epoch))
            if body == .neptune || body == .pluto {
                #expect(simd_distance(first.position, last.position) > 1)
            }
        }
    }
}

@MainActor
@Test func orbitSnapshotsFollowCurrentBodiesAndEarthAcrossCachedFrames() throws {
    let pipeline = makeOrbitPipeline(provider: KeplerCelestialStateProvider(planets: testPlanets))
    pipeline.requestPreparation(simulationTime: 0)
    let initial = try #require(pipeline.latestSnapshot)
    pipeline.requestPreparation(simulationTime: 5_000)
    let moved = try #require(pipeline.latestSnapshot)
    #expect(initial.orbits == moved.orbits)

    for orbit in moved.orbits {
        let packet = try #require(moved.planet(named: orbit.body.rawValue))
        let origin = packet.preciseWorldPosition + SIMD3(0.000_000_1, 0, 0)
        let points = orbit.renderPoints(in: moved, relativeTo: origin)
        let current = EphemerisCoordinates.renderPosition(packet.preciseWorldPosition, relativeTo: origin)
        #expect(points.contains(current))
        #expect(points.count == orbit.samples.count + 1)
        if orbit.body == .moon {
            let earth = try #require(moved.planet(named: "Earth"))
            let first = try #require(orbit.samples.first)
            #expect(points.first == SIMD3<Float>((earth.preciseWorldPosition - origin) + first.position))
        }
    }
}

@MainActor
@Test func replacingStateProviderInvalidatesOrbitCacheAndMissingGeometryIsOmitted() throws {
    let pipeline = makeOrbitPipeline(provider: CountingOrbitProvider())
    pipeline.requestPreparation(simulationTime: 0)
    let first = try #require(pipeline.latestSnapshot)
    let replacement = CountingOrbitProvider(offset: SIMD3(100, 0, 0))
    pipeline.setStateProvider(replacement)
    #expect(pipeline.latestSnapshot == nil)
    pipeline.requestPreparation(simulationTime: 0)
    let updated = try #require(pipeline.latestSnapshot)
    #expect(updated.orbits.first { $0.body == .earth } != first.orbits.first { $0.body == .earth })
    #expect(replacement.queryCount.withLock { $0 } > 2_000)

    pipeline.setStateProvider(SamplingFailureProvider())
    pipeline.requestPreparation(simulationTime: 0)
    let incomplete = try #require(pipeline.latestSnapshot)
    #expect(pipeline.preparationError == nil)
    #expect(incomplete.planet(named: "Mars") != nil)
    #expect(!incomplete.orbits.contains { $0.body == .mars })
    #expect(incomplete.orbits.contains { $0.body == .earth })
}

@Test func currentPositionReplacesMatchingSampleAndRetainsLocalPrecision() {
    let center = SIMD3<Double>(6_000.123456789, -200.987654321, 5_000.876543219)
    let orbit = CelestialOrbitSnapshot(body: .pluto, parent: nil, samples: [
        .init(epoch: 0, position: center - SIMD3(0.01, 0, 0)),
        .init(epoch: 1, position: center + SIMD3(0.001, 0, 0)),
        .init(epoch: 2, position: center + SIMD3(0.01, 0, 0))
    ])
    let body = CelestialBodySnapshot(planetName: "Pluto", baseModelMatrix: matrix_identity_float4x4,
                                     normalizedScale: 1, framingRadius: 1, surfaceRadius: 1,
                                     worldPosition: SIMD3<Float>(center), preciseWorldPosition: center)
    let scene = UniverseSceneSnapshot(frameID: 0, simulationTime: 1, planets: [body], orbits: [orbit])
    let origin = center + SIMD3(0.000_000_1, 0, 0)
    let points = orbit.renderPoints(in: scene, relativeTo: origin)
    #expect(points.count == 3)
    #expect(abs(Double(points[1].x) + 0.000_000_1) < 1e-12)
}

@MainActor
private func makeOrbitPipeline(provider: any CelestialStateProviding) -> UniverseSceneSnapshotPipeline {
    let pipeline = UniverseSceneSnapshotPipeline(planets: testPlanets, stateProvider: provider)
    pipeline.setPresentationMetrics(Dictionary(uniqueKeysWithValues: testPlanets.map {
        ($0.name, CelestialBodyPresentationMetrics(renderRadius: $0.radius,
                                                   framingRadius: $0.radius, surfaceRadius: $0.radius))
    }))
    return pipeline
}

private final class CountingOrbitProvider: CelestialStateProviding {
    let queryCount = Mutex(0)
    let offset: SIMD3<Double>

    init(offset: SIMD3<Double> = .zero) { self.offset = offset }

    func state(for body: CelestialBodyID, at seconds: Double) throws -> CelestialBodyState {
        queryCount.withLock { $0 += 1 }
        let state = try KeplerCelestialStateProvider(planets: testPlanets).state(for: body, at: seconds)
        return CelestialBodyState(positionKm: state.positionKm + offset,
                                  velocityKmPerSecond: state.velocityKmPerSecond,
                                  bodyFixedToEcliptic: state.bodyFixedToEcliptic)
    }
}

private struct SamplingFailureProvider: CelestialStateProviding {
    func state(for body: CelestialBodyID, at seconds: Double) throws -> CelestialBodyState {
        if body == .mars, seconds != 0 { throw CelestialStateError.invalidData }
        return try KeplerCelestialStateProvider(planets: testPlanets).state(for: body, at: seconds)
    }
}
