//
//  NavigationRenderHandler.swift
//  MetalModule
//
//  Created by max on 12.05.2026.
//

import Observation

/// Handles navigation events for MetalRenderer
@MainActor
@Observable
public final class NavigationRenderHandler: NavigationRenderHandlerProtocol {

    public var navigationSnapshot: NavigationRouteSnapshot = .idle {
        didSet {
            if navigationSnapshot.state == .completed {
                scheduleDoneNavigation()
            } else {
                pendingDoneNavigationTask?.cancel()
            }
        }
    }
    public var navigationCameraFollowEnabled = true

    @ObservationIgnored private var pendingDoneNavigationTask: Task<Void, Never>?

    weak var renderer: MetalRenderer?

    public init() {
    }

    private func scheduleDoneNavigation() {
        let routeID = navigationSnapshot.routeID

        pendingDoneNavigationTask?.cancel()
        pendingDoneNavigationTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(1_100))
            } catch {
                return
            }

            await MainActor.run {
                guard let self,
                      self.navigationSnapshot.state == .completed,
                      self.navigationSnapshot.routeID == routeID else {
                    return
                }

                self.doneNavigation()
            }
        }
    }
}

extension NavigationRenderHandler: NavigationRenderHandlerEventsProtocol {

    public func startNavigation(to destinationName: String) {
        renderer?.startNavigation(to: destinationName)
    }

    public func pauseNavigation() {
        renderer?.pauseNavigation()
    }

    public func resumeNavigation() {
        renderer?.resumeNavigation()
    }

    public func cancelNavigation() {
        renderer?.cancelNavigation()
    }

    public func doneNavigation() {
        renderer?.doneNavigation()
    }

    public func setNavigationCameraFollowEnabled(_ isEnabled: Bool) {
        navigationCameraFollowEnabled = isEnabled
        renderer?.setNavigationCameraFollowEnabled(isEnabled)
    }
}

@MainActor
protocol NavigationRenderHandlerProtocol: AnyObject {
    var navigationSnapshot: NavigationRouteSnapshot { get set }
    var navigationCameraFollowEnabled: Bool { get set }
}

@MainActor
public protocol NavigationRenderHandlerEventsProtocol: AnyObject {
    var navigationSnapshot: NavigationRouteSnapshot { get }
    var navigationCameraFollowEnabled: Bool { get set }

    func startNavigation(to destinationName: String)
    func pauseNavigation()
    func resumeNavigation()
    func cancelNavigation()
    func doneNavigation()
    func setNavigationCameraFollowEnabled(_ isEnabled: Bool)
}
