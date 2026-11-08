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
    }

    @Test(arguments: [0.0, 0.01, 20.0, 300.0])
    func readyCompletesWithinTwoSeconds(wait: Double) {
        let sequence = LaunchSequence()
        sequence.advance(by: wait)
        sequence.resourcesReady(reduceMotion: false)
        sequence.resourcesReady(reduceMotion: false)
        #expect(sequence.readyAt == wait)
        #expect(sequence.phase == .waiting)
        #expect(!sequence.advance(by: LaunchSequence.releaseDuration + 0.1))
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
        #expect(sequence.usesReducedMotion)
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

    @Test func enablingReducedMotionDuringDissolveDoesNotIncreaseOpacity() {
        let sequence = LaunchSequence()
        sequence.resourcesReady(reduceMotion: false)
        sequence.advance(by: 1.55)
        let opacity = sequence.opacity
        sequence.reduceMotionEnabled()
        #expect(abs(sequence.opacity - opacity) < 0.001)
        sequence.advance(by: 0.1)
        #expect(sequence.opacity < opacity)
        #expect(sequence.advance(by: 0.11))
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

    @Test func dioramaFlameAndReleaseFollowTheirRespectiveTriggers() {
        let waiting = LaunchDioramaFrame(elapsed: 0.44, readyAt: nil, liftProgress: 0)
        #expect(waiting.flameStrength == 0)
        #expect(waiting.release == 0)
        let burning = LaunchDioramaFrame(elapsed: 2, readyAt: nil, liftProgress: 0)
        #expect(burning.flameStrength == 1)
        #expect(burning.release == 0)
        let fastReady = LaunchDioramaFrame(elapsed: 0.18, readyAt: 0, liftProgress: 0)
        #expect(fastReady.flameStrength == 1)
        #expect(fastReady.release == 1)
    }

    @Test func dioramaImagesAreBundledAndDecodedAtBoundedResolution() throws {
        let assets = try #require(LaunchDioramaAssets.load())
        for (image, limit) in [(assets.closedPad, 1536), (assets.openPad, 1536),
                               (assets.rocket, 1024), (assets.smoke, 1024), (assets.flame, 1024)] {
            #expect(max(image.width, image.height) <= limit)
            #expect([CGImageAlphaInfo.first, .last, .premultipliedFirst, .premultipliedLast].contains(image.alphaInfo))
        }
        #expect(assets.closedPad.width == assets.openPad.width)
        #expect(assets.closedPad.height == assets.openPad.height)
        #expect(LaunchDioramaAssets.load(bundle: Bundle(for: LaunchBundleMarker.self)) == nil)
    }

    @Test(arguments: LaunchReviewSizes.all)
    func dioramaStaysCenteredAndNozzleTracksRocket(size: CGSize) {
        let layout = LaunchDioramaLayout(size: size)
        #expect(abs(layout.diameter - min(size.width, size.height) * 4 / 9) < 0.001)
        #expect(abs(layout.padRect.midX - size.width / 2) < 0.001)
        for progress in [0.0, 0.5, 1.0] {
            let rocket = layout.rocketRect(liftProgress: progress)
            let flame = layout.flameRect(liftProgress: progress, strength: 1, pulse: 1)
            let engine = layout.engine(liftProgress: progress)
            #expect(rocket.minY > 0 && rocket.maxY < size.height)
            #expect(abs(rocket.minY + rocket.height * 0.877 - engine.y) < 0.001)
            #expect(abs(flame.minY + flame.height * 0.12 - engine.y) < 0.001)
        }
    }

}

private final class LaunchBundleMarker: NSObject {}

/// Point sizes cover both native Duo displays and the supported window shapes.
enum LaunchReviewSizes {
    static let all: [CGSize] = [
        CGSize(width: 402, height: 874), CGSize(width: 874, height: 402),
        CGSize(width: 466, height: 678), CGSize(width: 678, height: 466),
        CGSize(width: 669, height: 951), CGSize(width: 951, height: 669),
        CGSize(width: 820, height: 1180), CGSize(width: 1180, height: 820),
        CGSize(width: 1024, height: 1366), CGSize(width: 1366, height: 1024),
        CGSize(width: 320, height: 900), CGSize(width: 500, height: 500),
        CGSize(width: 1100, height: 320)
    ]
}
