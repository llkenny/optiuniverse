import Foundation
import Testing
@testable import UniverseModule

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
