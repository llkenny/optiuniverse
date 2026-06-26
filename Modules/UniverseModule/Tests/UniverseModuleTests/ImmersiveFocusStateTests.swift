import CoreGraphics
import simd
import Testing
@testable import UniverseModule

@Test func immersiveFocusTransformMapsSelectedBodyInFrontOfUser() throws {
    var state = ImmersiveFocusState()
    state.focus(on: "Mars")
    let selectedPosition = SIMD3<Float>(2, 0.5, -4)

    let transform = try #require(
        state.transform(
            selectedBodyPositionAfterSceneOrigin: selectedPosition,
            framingRadius: 1
        )
    )

    expectVector(transform.project(selectedPosition),
                 equals: ImmersiveFocusState.targetCenter)
    #expect(ImmersiveFocusState.targetCenter.y > 0)
}

@Test func immersiveFocusTransformScalesByFramingRadius() throws {
    var state = ImmersiveFocusState()
    state.focus(on: "Jupiter")
    let selectedPosition = SIMD3<Float>(-3, 0, 8)
    let framingRadius: Float = 2

    let transform = try #require(
        state.transform(
            selectedBodyPositionAfterSceneOrigin: selectedPosition,
            framingRadius: framingRadius
        )
    )

    let rimPosition = selectedPosition + SIMD3<Float>(framingRadius, 0, 0)
    let mappedRadius = distance(transform.project(rimPosition),
                                ImmersiveFocusState.targetCenter)
    #expect(abs(mappedRadius - ImmersiveFocusState.targetVisualRadius) < 0.00001)
}

@Test func immersiveFocusZoomMultiplierClampsToComfortableRange() throws {
    var state = ImmersiveFocusState()
    state.focus(on: "Moon")
    let didScaleUp = state.scale(by: 100)
    #expect(didScaleUp)

    var transform = try #require(
        state.transform(
            selectedBodyPositionAfterSceneOrigin: .zero,
            framingRadius: 1
        )
    )
    var mappedRadius = distance(
        transform.project(SIMD3<Float>(1, 0, 0)),
        ImmersiveFocusState.targetCenter
    )
    #expect(
        abs(
            mappedRadius
                - ImmersiveFocusState.targetVisualRadius
                * ImmersiveFocusState.maximumZoomMultiplier
        ) < 0.00001
    )

    let didScaleDown = state.scale(by: 0.0001)
    #expect(didScaleDown)
    transform = try #require(
        state.transform(
            selectedBodyPositionAfterSceneOrigin: .zero,
            framingRadius: 1
        )
    )
    mappedRadius = distance(
        transform.project(SIMD3<Float>(1, 0, 0)),
        ImmersiveFocusState.targetCenter
    )
    #expect(
        abs(
            mappedRadius
                - ImmersiveFocusState.targetVisualRadius
                * ImmersiveFocusState.minimumZoomMultiplier
        ) < 0.00001
    )
}

@Test func immersiveFocusRotationKeepsSelectedBodyCentered() throws {
    var state = ImmersiveFocusState()
    state.focus(on: "Saturn")
    let didRotate = state.rotate(translation: CGSize(width: 40, height: 25))
    #expect(didRotate)
    let selectedPosition = SIMD3<Float>(3, -1, 6)

    let transform = try #require(
        state.transform(
            selectedBodyPositionAfterSceneOrigin: selectedPosition,
            framingRadius: 1
        )
    )

    expectVector(transform.project(selectedPosition),
                 equals: ImmersiveFocusState.targetCenter)
}

private extension float4x4 {
    func project(_ point: SIMD3<Float>) -> SIMD3<Float> {
        let projected = self * SIMD4<Float>(point, 1)
        return SIMD3<Float>(
            projected.x / projected.w,
            projected.y / projected.w,
            projected.z / projected.w
        )
    }
}

private func expectVector(_ lhs: SIMD3<Float>,
                          equals rhs: SIMD3<Float>,
                          tolerance: Float = 0.00001) {
    #expect(abs(lhs.x - rhs.x) <= tolerance)
    #expect(abs(lhs.y - rhs.y) <= tolerance)
    #expect(abs(lhs.z - rhs.z) <= tolerance)
}
