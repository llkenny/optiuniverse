import Foundation
import Testing
@testable import UniverseModule

@Test func playbackPauseResumeDoesNotJumpProgress() {
    let clock = ManualClock()
    let playback = RoutePlaybackController(clock: clock.time)

    playback.start(duration: 10)
    clock.now = 3
    #expect(abs(playback.progress - 0.3) < 0.0001)

    playback.pause()
    clock.now = 8
    #expect(abs(playback.progress - 0.3) < 0.0001)

    playback.resume()
    clock.now = 9
    #expect(abs(playback.progress - 0.4) < 0.0001)
}

@Test func playbackCompletesAndCancels() {
    let clock = ManualClock()
    let playback = RoutePlaybackController(clock: clock.time)

    playback.start(duration: 5)
    clock.now = 5
    playback.update()

    #expect(playback.isCompleted)
    #expect(playback.progress == 1)

    playback.cancel()
    #expect(!playback.isCompleted)
    #expect(playback.progress == 0)
}

private final class ManualClock {
    var now: TimeInterval = 0

    func time() -> TimeInterval {
        now
    }
}
