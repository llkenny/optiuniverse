import Foundation
import SwiftUI
import Testing
import UniverseModule
@testable import OptiUniverse

@Suite @MainActor
struct ReviewRequestCoordinatorTests {
    @Test func foregroundMilestoneAndPersistence() {
        let fixture = ReviewFixture()
        defer { fixture.cleanUp() }
        let coordinator = fixture.makeCoordinator()
        #expect(coordinator.foregroundSessionCount == 0)
        #expect(coordinator.navigationStartCount == 0)
        #expect(!coordinator.isEligible)

        recordSessions(2, on: coordinator)
        #expect(!coordinator.isEligible)
        recordSessions(1, on: coordinator)
        #expect(coordinator.isEligible)

        let relaunched = fixture.makeCoordinator()
        #expect(relaunched.foregroundSessionCount == 3)
        #expect(relaunched.navigationStartCount == 0)
        #expect(relaunched.isEligible)
        relaunched.scenePhaseChanged(.active)
        #expect(relaunched.foregroundSessionCount == 4)
    }

    @Test func foregroundSessionsIgnoreInactiveInterruptionsAndRepeatedCallbacks() {
        let fixture = ReviewFixture()
        defer { fixture.cleanUp() }
        let coordinator = fixture.makeCoordinator()
        for phase in [ScenePhase.inactive, .active, .active, .inactive, .active] {
            coordinator.scenePhaseChanged(phase)
        }
        #expect(coordinator.foregroundSessionCount == 1)
        for phase in [ScenePhase.inactive, .background, .background, .inactive, .active] {
            coordinator.scenePhaseChanged(phase)
        }
        #expect(coordinator.foregroundSessionCount == 2)
    }

    @Test func navigationMilestoneCountsOnlyDistinctSuccessfulStarts() {
        let fixture = ReviewFixture()
        defer { fixture.cleanUp() }
        let coordinator = fixture.makeCoordinator()
        let routeID = UUID()
        for state in [NavigationRouteState.idle, .preparing, .cancelled, .completed] {
            coordinator.navigationChanged(routeID: routeID, state: state)
        }
        coordinator.navigationChanged(routeID: nil, state: .running)
        #expect(coordinator.navigationStartCount == 0)

        for state in [NavigationRouteState.running, .running, .running, .completed, .cancelled] {
            coordinator.navigationChanged(routeID: routeID, state: state)
        }
        #expect(coordinator.navigationStartCount == 1)
        #expect(!coordinator.isEligible)

        coordinator.navigationChanged(routeID: UUID(), state: .running)
        #expect(coordinator.navigationStartCount == 2)
        #expect(coordinator.foregroundSessionCount == 0)
        #expect(coordinator.isEligible)
        #expect(fixture.makeCoordinator().navigationStartCount == 2)
    }

    @Test func requestWaitsTwoSecondsAndPersistsBeforeCallingStoreKit() async throws {
        let fixture = ReviewFixture()
        defer { fixture.cleanUp() }
        let delay = ControlledReviewDelay()
        let coordinator = fixture.makeCoordinator(sleep: { try await delay.sleep($0) })
        recordSessions(3, on: coordinator)
        var requests = 0
        let request: @MainActor @Sendable () -> Void = {
            requests += 1
            let reloaded = fixture.makeCoordinator()
            #expect(reloaded.lastRequestDate == fixture.date)
            #expect(reloaded.lastRequestVersion == "1.6")
            #expect(!reloaded.isEligible)
        }
        coordinator.updatePresentation(safeContext, requestReview: request)
        let task = try #require(coordinator.pendingRequest)
        await delay.waitForCall(1)
        #expect(delay.durations == [.seconds(2)])
        #expect(requests == 0)
        #expect(coordinator.lastRequestDate == nil)

        coordinator.updatePresentation(safeContext, requestReview: request)
        delay.resumeNext()
        await task.value
        #expect(requests == 1)
        #expect(coordinator.pendingRequest == nil)
        coordinator.updatePresentation(safeContext, requestReview: request)
        recordSessions(3, on: coordinator)
        #expect(coordinator.pendingRequest == nil)
        #expect(delay.durations.count == 1)
    }

    @Test(arguments: ReviewBlocker.allCases)
    func unsafePresentationDefersRequest(blocker: ReviewBlocker) async throws {
        let fixture = ReviewFixture()
        defer { fixture.cleanUp() }
        let delay = ControlledReviewDelay()
        let coordinator = fixture.makeCoordinator(sleep: { try await delay.sleep($0) })
        recordSessions(3, on: coordinator)
        var requests = 0
        coordinator.updatePresentation(blocker.context, requestReview: { requests += 1 })
        #expect(coordinator.pendingRequest == nil)
        #expect(coordinator.lastRequestDate == nil)

        coordinator.updatePresentation(safeContext, requestReview: { requests += 1 })
        let task = try #require(coordinator.pendingRequest)
        await delay.waitForCall(1)
        delay.resumeNext()
        await task.value
        #expect(requests == 1)
    }

    @Test(arguments: ReviewBlocker.allCases)
    func unsafePresentationCancelsDelayAndRestartsFullDelay(blocker: ReviewBlocker) async throws {
        let fixture = ReviewFixture()
        defer { fixture.cleanUp() }
        let delay = ControlledReviewDelay()
        let coordinator = fixture.makeCoordinator(sleep: { try await delay.sleep($0) })
        recordSessions(3, on: coordinator)
        var requests = 0
        coordinator.updatePresentation(safeContext, requestReview: { requests += 1 })
        let originalTask = try #require(coordinator.pendingRequest)
        await delay.waitForCall(1)

        coordinator.updatePresentation(blocker.context, requestReview: { requests += 1 })
        #expect(originalTask.isCancelled)
        #expect(coordinator.pendingRequest == nil)
        coordinator.updatePresentation(safeContext, requestReview: { requests += 1 })
        let replacementTask = try #require(coordinator.pendingRequest)
        await delay.waitForCall(2)

        // Even a sleeper that ignores cancellation cannot deliver an obsolete request.
        delay.resumeNext()
        await originalTask.value
        #expect(requests == 0)
        #expect(coordinator.lastRequestDate == nil)
        #expect(coordinator.pendingRequest != nil)
        delay.resumeNext()
        await replacementTask.value
        #expect(requests == 1)
        #expect(delay.durations == [.seconds(2), .seconds(2)])
    }

    @Test(arguments: [NavigationRouteState.completed, .cancelled])
    func secondNavigationStartWaitsUntilRouteEnds(endState: NavigationRouteState) async throws {
        let fixture = ReviewFixture()
        defer { fixture.cleanUp() }
        let delay = ControlledReviewDelay()
        let coordinator = fixture.makeCoordinator(sleep: { try await delay.sleep($0) })
        coordinator.scenePhaseChanged(.active)
        var requests = 0
        coordinator.updatePresentation(safeContext, requestReview: { requests += 1 })
        coordinator.navigationChanged(routeID: UUID(), state: .running)
        coordinator.navigationChanged(routeID: nil, state: .cancelled)
        let secondRoute = UUID()
        coordinator.navigationChanged(routeID: secondRoute, state: .running)
        #expect(coordinator.isEligible)
        #expect(coordinator.pendingRequest == nil)
        #expect(coordinator.pendingRequest == nil)
        coordinator.navigationChanged(routeID: secondRoute, state: .running)
        #expect(coordinator.navigationStartCount == 2)
        coordinator.navigationChanged(routeID: secondRoute, state: endState)
        let task = try #require(coordinator.pendingRequest)
        await delay.waitForCall(1)
        delay.resumeNext()
        await task.value
        #expect(requests == 1)
    }

    @Test func appPhaseAndViewDisappearanceCancelPendingRequests() async throws {
        let fixture = ReviewFixture()
        defer { fixture.cleanUp() }
        let delay = ControlledReviewDelay()
        let coordinator = fixture.makeCoordinator(sleep: { try await delay.sleep($0) })
        recordSessions(3, on: coordinator)
        var requests = 0
        coordinator.updatePresentation(safeContext, requestReview: { requests += 1 })
        let task = try #require(coordinator.pendingRequest)
        await delay.waitForCall(1)
        coordinator.scenePhaseChanged(.inactive)
        delay.resumeNext()
        await task.value
        #expect(requests == 0)

        coordinator.scenePhaseChanged(.active)
        let nextTask = try #require(coordinator.pendingRequest)
        await delay.waitForCall(2)
        coordinator.stopPresenting()
        delay.resumeNext()
        await nextTask.value
        #expect(requests == 0)
        #expect(coordinator.pendingRequest == nil)
        #expect(coordinator.lastRequestDate == nil)
        #expect(coordinator.foregroundSessionCount == 3)
    }

    @Test func repeatRequiresNewerMarketingVersionAndFullCooldown() async throws {
        let fixture = ReviewFixture()
        defer { fixture.cleanUp() }
        let coordinator = fixture.makeCoordinator(sleep: { _ in })
        recordSessions(3, on: coordinator)
        coordinator.updatePresentation(safeContext, requestReview: {})
        await (try #require(coordinator.pendingRequest)).value

        let cooldown: TimeInterval = 120 * 24 * 60 * 60
        for (version, elapsed, eligible) in [
            ("1.6", cooldown * 2, false),
            ("1.5", cooldown * 2, false),
            ("1.7", cooldown - 1, false),
            ("1.7", cooldown, true),
            ("1.10", cooldown, true),
            ("2.0", -1, false),
            ("", cooldown * 2, false)
        ] {
            let updated = ReviewRequestCoordinator(defaults: fixture.defaults,
                                                   appVersion: version,
                                                   now: { fixture.date.addingTimeInterval(elapsed) })
            #expect(updated.isEligible == eligible)
            #expect(updated.foregroundSessionCount == 3)
        }
    }

    @Test func eligibilityIsRecheckedAfterDelay() async throws {
        let fixture = ReviewFixture()
        defer { fixture.cleanUp() }
        let initial = fixture.makeCoordinator(sleep: { _ in })
        recordSessions(3, on: initial)
        initial.updatePresentation(safeContext, requestReview: {})
        await (try #require(initial.pendingRequest)).value

        let delay = ControlledReviewDelay()
        var date = fixture.date.addingTimeInterval(120 * 24 * 60 * 60)
        let updated = ReviewRequestCoordinator(defaults: fixture.defaults, appVersion: "1.7",
                                               now: { date }, sleep: { try await delay.sleep($0) })
        updated.scenePhaseChanged(.active)
        var requests = 0
        updated.updatePresentation(safeContext, requestReview: { requests += 1 })
        let task = try #require(updated.pendingRequest)
        await delay.waitForCall(1)
        date = fixture.date
        delay.resumeNext()
        await task.value
        #expect(requests == 0)
        #expect(updated.lastRequestVersion == "1.6")
    }

    private var safeContext: ReviewRequestCoordinator.PresentationContext {
        .init(isLoaded: true, isSceneActive: true)
    }

    private func recordSessions(_ count: Int, on coordinator: ReviewRequestCoordinator) {
        for _ in 0..<count {
            coordinator.scenePhaseChanged(.background)
            coordinator.scenePhaseChanged(.active)
        }
    }
}

enum ReviewBlocker: CaseIterable, Sendable {
    case loading, inactive, preparing, running, legalSheet, objectInfo

    @MainActor var context: ReviewRequestCoordinator.PresentationContext {
        var context = ReviewRequestCoordinator.PresentationContext(isLoaded: true, isSceneActive: true)
        switch self {
        case .loading: context.isLoaded = false
        case .inactive: context.isSceneActive = false
        case .preparing: context.navigationState = .preparing
        case .running: context.navigationState = .running
        case .legalSheet: context.isLegalSheetPresented = true
        case .objectInfo: context.isObjectInfoPresented = true
        }
        return context
    }
}

@MainActor
private struct ReviewFixture {
    let suiteName: String
    let defaults: UserDefaults
    let date = Date(timeIntervalSince1970: 1_800_000_000)

    init() {
        suiteName = "ReviewRequestCoordinatorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    func makeCoordinator(sleep: @escaping @MainActor @Sendable (Duration) async throws -> Void = {
        try await Task.sleep(for: $0)
    }) -> ReviewRequestCoordinator {
        ReviewRequestCoordinator(defaults: defaults, appVersion: "1.6", now: { date }, sleep: sleep)
    }

    func cleanUp() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

@MainActor
private final class ControlledReviewDelay {
    private(set) var durations: [Duration] = []
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private var callWaiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func sleep(_ duration: Duration) async throws {
        await withCheckedContinuation { continuation in
            durations.append(duration)
            continuations.append(continuation)
            let ready = callWaiters.filter { $0.0 <= durations.count }
            callWaiters.removeAll { $0.0 <= durations.count }
            ready.forEach { $0.1.resume() }
        }
    }

    func waitForCall(_ count: Int) async {
        guard durations.count < count else { return }
        await withCheckedContinuation { callWaiters.append((count, $0)) }
    }

    func resumeNext() {
        continuations.removeFirst().resume()
    }
}
