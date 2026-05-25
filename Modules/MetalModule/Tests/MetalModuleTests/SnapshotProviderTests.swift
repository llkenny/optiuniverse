import Testing
@testable import MetalModule

@MainActor
@Test func snapshotProviderReturnsLatestPreparedSnapshot() {
    let snapshot = PreparedRenderSnapshot(frameID: 7,
                                          simulationTime: 12,
                                          planets: [])
    let source = FakePreparedRenderSnapshotSource(latestSnapshot: snapshot)
    let provider = SnapshotProvider(snapshotSource: source)

    #expect(provider.latestSnapshot?.frameID == 7)
    #expect(provider.latestSnapshot?.simulationTime == 12)
}

@MainActor
@Test func snapshotProviderForwardsPreparationRequests() {
    let source = FakePreparedRenderSnapshotSource()
    let provider = SnapshotProvider(snapshotSource: source)

    provider.requestPreparation(simulationTime: 42)

    #expect(source.requestedSimulationTimes == [42])
}

@MainActor
private final class FakePreparedRenderSnapshotSource: PreparedRenderSnapshotProviding {
    var latestSnapshot: PreparedRenderSnapshot?
    var requestedSimulationTimes: [Float] = []

    init(latestSnapshot: PreparedRenderSnapshot? = nil) {
        self.latestSnapshot = latestSnapshot
    }

    func requestPreparation(simulationTime: Float) {
        requestedSimulationTimes.append(simulationTime)
    }
}
