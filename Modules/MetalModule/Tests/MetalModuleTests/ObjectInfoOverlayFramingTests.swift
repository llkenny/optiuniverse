import CoreGraphics
import simd
import Testing
@testable import MetalModule

@MainActor
@Test func objectInfoOverlayFramingStartsAtDefaultProjection() {
    let state = ObjectInfoOverlayFramingState()

    let adjustment = state.advance(delta: 1)

    #expect(adjustment.verticalFieldOfView == CameraFit.verticalFieldOfView)
    #expect(adjustment.verticalCenterOffset == 0)
}

@MainActor
@Test func objectInfoOverlayFramingMovesCenteredObjectUp() {
    let state = ObjectInfoOverlayFramingState()
    state.setPresentation(isPresented: true,
                          bottomInset: 300,
                          viewportHeight: 1_000)

    let adjustment = state.advance(delta: 1)
    let defaultProjection = float4x4.perspective(
        fov: CameraFit.verticalFieldOfView,
        aspect: 1,
        near: 0.1,
        far: 100
    )
    let adjustedProjection = float4x4.perspective(
        fov: adjustment.verticalFieldOfView,
        aspect: 1,
        near: 0.1,
        far: 100,
        verticalCenterOffset: adjustment.verticalCenterOffset
    )
    let centeredPoint = SIMD4<Float>(0, 0, 1, 1)

    #expect(screenY(project(centeredPoint, with: adjustedProjection)) <
            screenY(project(centeredPoint, with: defaultProjection)))
}

@MainActor
@Test func objectInfoOverlayFramingZoomsOutWithoutChangingClipPlanes() {
    let state = ObjectInfoOverlayFramingState()
    state.setPresentation(isPresented: true,
                          bottomInset: 400,
                          viewportHeight: 1_000)

    let adjustment = state.advance(delta: 1)
    let projection = CameraProjectionParameters(
        nearPlane: 0.2,
        farPlane: 80,
        verticalFieldOfView: adjustment.verticalFieldOfView,
        verticalCenterOffset: adjustment.verticalCenterOffset
    )

    #expect(projection.verticalFieldOfView > CameraFit.verticalFieldOfView)
    #expect(projection.verticalCenterOffset < 0)
    #expect(projection.nearPlane == 0.2)
    #expect(projection.farPlane == 80)
}

@Test func projectionParameterClippingUpdatesPreserveComposition() {
    let projection = CameraProjectionParameters(
        nearPlane: 0.1,
        farPlane: 100,
        verticalFieldOfView: CameraFit.verticalFieldOfView * 1.08,
        verticalCenterOffset: -0.2
    )

    let updatedProjection = projection.withClippingPlanes(nearPlane: 0.05,
                                                          farPlane: 200)

    #expect(updatedProjection.nearPlane == 0.05)
    #expect(updatedProjection.farPlane == 200)
    #expect(updatedProjection.verticalFieldOfView == projection.verticalFieldOfView)
    #expect(updatedProjection.verticalCenterOffset == projection.verticalCenterOffset)
}

private func project(_ point: SIMD4<Float>,
                     with matrix: float4x4) -> SIMD3<Float> {
    let clipPosition = matrix * point
    return SIMD3<Float>(clipPosition.x / clipPosition.w,
                        clipPosition.y / clipPosition.w,
                        clipPosition.z / clipPosition.w)
}

private func screenY(_ ndc: SIMD3<Float>) -> Float {
    (ndc.y + 1) * 0.5
}
