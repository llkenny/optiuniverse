import Foundation
import Observation
import SwiftUI
import UniverseModule

/// App-owned engagement history and scheduling for StoreKit's best-effort review request.
@MainActor
@Observable
final class ReviewRequestCoordinator {
    struct PresentationContext: Equatable {
        var isLoaded = false
        var isSceneActive = false
        var navigationState: NavigationRouteState = .idle
        var isLegalSheetPresented = false
        var isObjectInfoPresented = false

        var isSafe: Bool {
            isLoaded && isSceneActive && !isLegalSheetPresented && !isObjectInfoPresented
                && navigationState != .preparing
                && navigationState != .running
        }
    }

    private enum Key {
        static let foregroundSessions = "reviewRequest.foregroundSessions"
        static let navigationStarts = "reviewRequest.navigationStarts"
        static let lastRequestDate = "reviewRequest.lastRequestDate"
        static let lastRequestVersion = "reviewRequest.lastRequestVersion"
    }

    private(set) var foregroundSessionCount: Int
    private(set) var navigationStartCount: Int
    private(set) var lastRequestDate: Date?
    private(set) var lastRequestVersion: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let appVersion: String
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let sleep: @MainActor @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var hasCountedForegroundSession = false
    @ObservationIgnored private var isAppActive = false
    @ObservationIgnored private var countedRouteIDs: Set<UUID> = []
    @ObservationIgnored private var context = PresentationContext()
    @ObservationIgnored private var requestReview: (@MainActor () -> Void)?
    @ObservationIgnored private var pendingRequestID: UUID?
    @ObservationIgnored private(set) var pendingRequest: Task<Void, Never>?

    init(defaults: UserDefaults = .standard,
         appVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
         now: @escaping () -> Date = Date.init,
         sleep: @escaping @MainActor @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.defaults = defaults
        self.appVersion = appVersion
        self.now = now
        self.sleep = sleep
        foregroundSessionCount = defaults.integer(forKey: Key.foregroundSessions)
        navigationStartCount = defaults.integer(forKey: Key.navigationStarts)
        lastRequestDate = defaults.object(forKey: Key.lastRequestDate) as? Date
        lastRequestVersion = defaults.string(forKey: Key.lastRequestVersion)
    }

    var isEligible: Bool {
        guard !appVersion.isEmpty,
              foregroundSessionCount >= 3 || navigationStartCount >= 2 else { return false }

        if let lastRequestVersion,
           appVersion.compare(lastRequestVersion, options: .numeric) != .orderedDescending {
            return false
        }
        if let lastRequestDate, now().timeIntervalSince(lastRequestDate) < 120 * 24 * 60 * 60 {
            return false
        }
        return true
    }

    /// Use the App's aggregate scene phase so an inactive interruption is not a new session.
    func scenePhaseChanged(_ phase: ScenePhase) {
        isAppActive = phase == .active
        switch phase {
        case .active:
            if !hasCountedForegroundSession {
                hasCountedForegroundSession = true
                foregroundSessionCount += 1
                defaults.set(foregroundSessionCount, forKey: Key.foregroundSessions)
            }
        case .background:
            hasCountedForegroundSession = false
        case .inactive:
            break
        @unknown default:
            break
        }
        scheduleIfNeeded()
    }

    func navigationChanged(routeID: UUID?, state: NavigationRouteState) {
        // Update the blocker before counting: the second start must never prompt mid-flight.
        context.navigationState = state
        if state == .running, let routeID, countedRouteIDs.insert(routeID).inserted {
            navigationStartCount += 1
            defaults.set(navigationStartCount, forKey: Key.navigationStarts)
        }
        scheduleIfNeeded()
    }

    func updatePresentation(_ context: PresentationContext,
                            requestReview: @escaping @MainActor () -> Void) {
        self.context = context
        self.requestReview = requestReview
        scheduleIfNeeded()
    }

    func stopPresenting() {
        context = PresentationContext()
        requestReview = nil
        cancelPendingRequest()
    }

    private func scheduleIfNeeded() {
        guard isAppActive, context.isSafe, isEligible, requestReview != nil else {
            cancelPendingRequest()
            return
        }
        guard pendingRequest == nil else { return }

        let requestID = UUID()
        pendingRequestID = requestID
        let sleep = self.sleep
        pendingRequest = Task { @MainActor [weak self] in
            do {
                try await sleep(.seconds(2))
                try Task.checkCancellation()
            } catch {
                if self?.pendingRequestID == requestID {
                    self?.cancelPendingRequest()
                }
                return
            }

            guard let self, self.pendingRequestID == requestID else { return }
            self.pendingRequest = nil
            self.pendingRequestID = nil
            guard self.isAppActive, self.context.isSafe, self.isEligible,
                  let requestReview = self.requestReview else { return }

            // StoreKit gives no display/submission callback. Persist the attempt, not a claimed review.
            self.lastRequestDate = self.now()
            self.lastRequestVersion = self.appVersion
            self.defaults.set(self.lastRequestDate, forKey: Key.lastRequestDate)
            self.defaults.set(self.lastRequestVersion, forKey: Key.lastRequestVersion)
            requestReview()
        }
    }

    private func cancelPendingRequest() {
        pendingRequest?.cancel()
        pendingRequest = nil
        pendingRequestID = nil
    }
}
