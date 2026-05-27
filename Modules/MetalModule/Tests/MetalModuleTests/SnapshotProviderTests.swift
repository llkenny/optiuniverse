import CoreGraphics
import simd
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
@Test func snapshotProviderUsesExplicitProjectionParameters() {
    let source = FakePreparedRenderSnapshotSource()
    let provider = SnapshotProvider(snapshotSource: source)
    let viewportSize = CGSize(width: 200, height: 100)
    let projection = CameraProjectionParameters(nearPlane: 0.25,
                                                farPlane: 42)

    let cameraSnapshot = provider.makeCameraSnapshot(viewportSize: viewportSize,
                                                     projection: projection)
    let expectedProjection = float4x4.perspective(fov: CameraFit.verticalFieldOfView,
                                                  aspect: 2,
                                                  near: projection.nearPlane,
                                                  far: projection.farPlane)

    expectMatrix(cameraSnapshot.projectionMatrix,
                 equals: expectedProjection)
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

private func expectMatrix(_ lhs: float4x4,
                          equals rhs: float4x4,
                          tolerance: Float = 0.000001) {
    for column in 0..<4 {
        for row in 0..<4 {
            #expect(abs(lhs[column][row] - rhs[column][row]) <= tolerance)
        }
    }
}
