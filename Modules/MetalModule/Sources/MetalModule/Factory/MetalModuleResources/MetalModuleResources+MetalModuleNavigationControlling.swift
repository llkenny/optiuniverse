//
//  MetalModuleResources+MetalModuleNavigationControlling.swift
//  MetalModule
//
//  Created by max on 24.05.2026.
//

extension MetalModuleResources: MetalModuleNavigationControlling {

    public var navigation: any MetalModuleNavigationControlling {
        self
    }

    public func startNavigation(to name: String) {
        navigationController.startNavigation(to: name)
    }

    public func pauseNavigation() {
        navigationController.pauseNavigation()
    }

    public func resumeNavigation() {
        navigationController.resumeNavigation()
    }

    public func cancelNavigation() {
        navigationController.cancelNavigation()
    }

    public func doneNavigation() {
        navigationController.doneNavigation()
    }

    public func setNavigationCameraFollowEnabled(_ isEnabled: Bool) {
        navigationController.setNavigationCameraFollowEnabled(isEnabled)
    }
}
