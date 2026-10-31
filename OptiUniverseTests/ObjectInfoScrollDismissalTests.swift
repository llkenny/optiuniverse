import Testing
@testable import OptiUniverse

struct ObjectInfoScrollDismissalTests {
    @Test func scrollingBackToTheTopDoesNotDismiss() {
        var state = ObjectInfoScrollDismissalState()
        state.begin(offset: 200)
        state.update(offset: -100)
        let dismisses = state.end(offset: -100, velocity: -1_000)
        #expect(!dismisses)
    }

    @Test func deliberatePullFromTopDismissesOnce() {
        var state = ObjectInfoScrollDismissalState()
        state.begin(offset: 0)
        state.update(offset: -90)
        let firstRelease = state.end(offset: -30, velocity: 0)
        let repeatedRelease = state.end(offset: -90, velocity: 0)
        #expect(firstRelease)
        #expect(!repeatedRelease)
    }

    @Test func fastPullUsesPredictedDistanceButOrdinaryScrollingDoesNot() {
        var state = ObjectInfoScrollDismissalState()
        state.begin(offset: 0)
        let fastPull = state.end(offset: -20, velocity: -700)
        #expect(fastPull)
        state.begin(offset: 0)
        let normalScroll = state.end(offset: 100, velocity: 1_000)
        #expect(!normalScroll)
        state.begin(offset: 0)
        let smallPull = state.end(offset: -20, velocity: 0)
        #expect(!smallPull)
    }

    @Test func newTouchClearsPreviousPullAndRejectsInvalidOffsets() {
        var state = ObjectInfoScrollDismissalState()
        state.begin(offset: 0)
        state.update(offset: -100)
        state.begin(offset: .nan)
        let invalidPull = state.end(offset: -100, velocity: -.infinity)
        #expect(!invalidPull)
        state.begin(offset: 0)
        let newTouch = state.end(offset: 0, velocity: 0)
        #expect(!newTouch)
    }
}
