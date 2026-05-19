import simd
import Testing
@testable import MetalModule

@Test func cameraTransitionProgressClampsAtOne() throws {
    var transition = CameraTransition(
        start: CameraTransition.Frame(target: .zero, distance: 2),
        destination: .fixed(target: SIMD3<Float>(10, 0, 0), distance: 8),
        duration: 1
    )

    let frame = try #require(transition.advance(delta: 2) { destination in
        guard case .fixed(let target, let distance) = destination else { return nil }
        return CameraTransition.Frame(target: target, distance: distance)
    })

    #expect(transition.progress == 1)
    #expect(transition.isComplete)
    #expect(frame.target == SIMD3<Float>(10, 0, 0))
    #expect(frame.distance == 8)
}

@Test func cameraTransitionCubicEaseStartsAndEndsExactly() throws {
    let start = CameraTransition.Frame(target: SIMD3<Float>(1, 2, 3), distance: 4)
    let end = CameraTransition.Frame(target: SIMD3<Float>(5, 6, 7), distance: 8)

    #expect(CameraTransition.interpolate(from: start,
                                         to: end,
                                         progress: CameraTransition.easeInOutCubic(0)) == start)
    #expect(CameraTransition.interpolate(from: start,
                                         to: end,
                                         progress: CameraTransition.easeInOutCubic(1)) == end)
}

@Test func cameraTransitionMidwayProgressIsSmoothAndMonotonic() {
    let early = CameraTransition.easeInOutCubic(0.25)
    let middle = CameraTransition.easeInOutCubic(0.5)
    let late = CameraTransition.easeInOutCubic(0.75)

    #expect(early > 0)
    #expect(early < middle)
    #expect(abs(middle - 0.5) < 0.0001)
    #expect(middle < late)
    #expect(late < 1)
}

@Test func cameraTransitionMissingDestinationDoesNotAdvance() {
    var transition = CameraTransition(
        start: CameraTransition.Frame(target: .zero, distance: 2),
        destination: .planet(name: "Mars"),
        duration: 1
    )

    let frame = transition.advance(delta: 0.5) { _ in nil }

    #expect(frame == nil)
    #expect(transition.progress == 0)
    #expect(!transition.isComplete)
}
