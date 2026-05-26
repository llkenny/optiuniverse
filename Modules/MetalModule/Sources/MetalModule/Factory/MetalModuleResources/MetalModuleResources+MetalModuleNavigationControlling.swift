//
//  MetalModuleResources+MetalModuleNavigationControlling.swift
//  MetalModule
//
//  Created by max on 24.05.2026.
//

extension MetalModuleResources {

    public var navigation: any MetalModuleNavigationControlling {
        navigationController
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

    private func doneNavigation() {
        navigationController.doneNavigation()
    }
}
