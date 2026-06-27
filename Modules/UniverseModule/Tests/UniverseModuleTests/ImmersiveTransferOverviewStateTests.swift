import simd
import Testing
@testable import UniverseModule

@Test func immersiveTransferOverviewCentersTargetAndUsesInverseCameraOrientation() throws {
    var state = ImmersiveTransferOverviewState()
    let target = SIMD3<Float>(3, -2, 5)
    let orientation = simd_quatf(angle: -.pi * 0.25,
                                 axis: SIMD3<Float>(1, 0, 0))
    let cameraPose = CameraPose(target: target,
                                distance: 4,
                                orientation: orientation)

    state.begin()
    let transform = state.persist(cameraPose: cameraPose,
                                  targetAfterSceneOrigin: target)
    #expect(transform != nil)
    guard let transform else { return }

    let expectedScale = simd_length(ImmersiveFocusState.targetCenter) / cameraPose.distance
    expectVector(transform.project(target), equals: ImmersiveFocusState.targetCenter)

    let mappedForward = transform.project(target + SIMD3<Float>(0, 0, 1))
        - ImmersiveFocusState.targetCenter
    let expectedForward = orientation.inverse.act(SIMD3<Float>(0, 0, expectedScale))
    expectVector(mappedForward, equals: expectedForward)
}

private extension float4x4 {
    func project(_ point: SIMD3<Float>) -> SIMD3<Float> {
        let projected = self * SIMD4<Float>(point, 1)
        return SIMD3<Float>(projected.x / projected.w,
                            projected.y / projected.w,
                            projected.z / projected.w)
    }
}

private func expectVector(_ lhs: SIMD3<Float>,
                          equals rhs: SIMD3<Float>,
                          tolerance: Float = 0.00001) {
    #expect(abs(lhs.x - rhs.x) <= tolerance)
    #expect(abs(lhs.y - rhs.y) <= tolerance)
    #expect(abs(lhs.z - rhs.z) <= tolerance)
}
