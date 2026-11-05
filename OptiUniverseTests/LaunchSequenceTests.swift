import CoreGraphics
import Foundation
import Testing
@testable import OptiUniverse

@Suite @MainActor
struct LaunchSequenceTests {
    @Test func longLoadingNeverStartsLift() {
        let sequence = LaunchSequence()
        for _ in 0..<300 {
            #expect(!sequence.advance(by: 1))
        }
        #expect(sequence.phase == .waiting)
        #expect(sequence.liftProgress == 0)
        #expect(sequence.opacity == 1)
        #expect(sequence.ignition > 0)
    }

    @Test(arguments: [0.0, 0.01, 20.0, 300.0])
    func readyCompletesWithinTwoSeconds(wait: Double) {
        let sequence = LaunchSequence()
        sequence.advance(by: wait)
        sequence.resourcesReady(reduceMotion: false)
        sequence.resourcesReady(reduceMotion: false)
        #expect(sequence.readyAt == wait)
        #expect(sequence.phase == .waiting)
        #expect(!sequence.advance(by: LaunchSequence.ignitionDuration + 0.1))
        #expect(sequence.phase == .lifting)
        #expect(sequence.liftProgress > 0)
        #expect(sequence.opacity == 1)
        #expect(!sequence.advance(by: LaunchSequence.liftDuration))
        #expect(sequence.phase == .dissolving)
        #expect(sequence.liftProgress == 1)
        #expect(sequence.opacity > 0 && sequence.opacity < 1)
        #expect(sequence.advance(by: LaunchSequence.fadeDuration))
        #expect(sequence.phase == .completed)
        #expect(sequence.opacity == 0)
        #expect(sequence.elapsed - wait < 1.9)
        #expect(!sequence.advance(by: 20))
    }

    @Test func reducedMotionHasNoLiftAndOnlyShortFade() {
        let sequence = LaunchSequence()
        sequence.resourcesReady(reduceMotion: true)
        #expect(sequence.phase == .dissolving)
        #expect(sequence.ignition == 0)
        #expect(!sequence.advance(by: 0.1))
        #expect(sequence.liftProgress == 0)
        #expect(abs(sequence.opacity - 0.5) < 0.001)
        #expect(sequence.advance(by: 0.11))
    }

    @Test func enablingReducedMotionDuringFlightFinishesWithShortFade() {
        let sequence = LaunchSequence()
        sequence.resourcesReady(reduceMotion: false)
        sequence.advance(by: 0.6)
        sequence.reduceMotionEnabled()
        #expect(sequence.liftProgress == 0)
        #expect(sequence.advance(by: 0.21))
    }

    @Test func cancellationSuppressesCompletionAndRetryResetsEverything() {
        let sequence = LaunchSequence()
        sequence.resourcesReady(reduceMotion: false)
        sequence.advance(by: 0.5)
        sequence.cancel()
        sequence.resourcesReady(reduceMotion: true)
        #expect(!sequence.advance(by: 10))
        #expect(sequence.phase == .cancelled)
        sequence.reset()
        #expect(sequence.phase == .waiting)
        #expect(sequence.readyAt == nil)
        #expect(sequence.elapsed == 0)
        #expect(sequence.opacity == 1)
        sequence.resourcesReady(reduceMotion: false)
        #expect(sequence.advance(by: 1.8))
        #expect(!sequence.advance(by: 1.8))
    }

    @Test func invalidClockDeltasCannotBreakSequence() {
        let sequence = LaunchSequence()
        for delta in [-1.0, .nan, .infinity] {
            #expect(!sequence.advance(by: delta))
        }
        #expect(sequence.elapsed == 0)
        // No call to advance while inactive means time is frozen, including after readiness.
        sequence.resourcesReady(reduceMotion: false)
        #expect(sequence.phase == .waiting)
    }

    @Test func bundledImagesLoadAndMissingBundleFailsSafely() throws {
        let assets = try #require(N1LaunchAssets.load())
        let alpha = try #require(assets.rocket.cgImage).alphaInfo
        #expect([CGImageAlphaInfo.first, .last, .premultipliedFirst, .premultipliedLast].contains(alpha))
        #expect(assets.rocket.size.height > assets.rocket.size.width)
        let vaporAlpha = try #require(assets.vapor.cgImage).alphaInfo
        #expect([CGImageAlphaInfo.first, .last, .premultipliedFirst, .premultipliedLast].contains(vaporAlpha))
        #expect(N1LaunchAssets.load(bundle: Bundle(for: LaunchBundleMarker.self)) == nil)
    }

    @Test(arguments: [
        CGSize(width: 320, height: 874), CGSize(width: 402, height: 874),
        CGSize(width: 874, height: 402), CGSize(width: 640, height: 960),
        CGSize(width: 1024, height: 1366), CGSize(width: 1366, height: 1024),
        CGSize(width: 500, height: 500), CGSize(width: 1100, height: 320)
    ])
    func photographKeepsWholeRocketVisible(size: CGSize) {
        let layout = N1LaunchLayout(size: size)
        let top = layout.point(x: 329, y: 0)
        let baseLeft = layout.point(x: 132, y: 1465)
        let baseRight = layout.point(x: 498, y: 1465)
        #expect(top.y >= 0)
        #expect(baseLeft.x >= 0)
        #expect(baseRight.x <= size.width)
        #expect(baseLeft.y < size.height)
        #expect(layout.engine.y - layout.liftDistance(progress: 1) < 0)
        #expect(layout.backgroundOrigin.x <= 0)
        #expect(layout.backgroundOrigin.x + layout.backgroundSize.width >= size.width)
        #expect(abs(layout.backgroundOrigin.y + layout.backgroundSize.height - size.height) < 0.001)
    }
}

private final class LaunchBundleMarker: NSObject {}
