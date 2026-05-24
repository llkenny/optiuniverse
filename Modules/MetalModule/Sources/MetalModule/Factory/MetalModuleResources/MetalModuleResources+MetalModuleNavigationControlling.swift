//
//  MetalModuleResources+MetalModuleNavigationControlling.swift
//  MetalModule
//
//  Created by max on 24.05.2026.
//

extension MetalModuleResources: MetalModuleNavigationControlling {
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

    func scheduleDoneNavigation() {
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
