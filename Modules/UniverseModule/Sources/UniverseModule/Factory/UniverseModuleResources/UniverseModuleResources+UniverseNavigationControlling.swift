//
//  UniverseModuleResources+UniverseNavigationControlling.swift
//  UniverseModule
//
//  Created by max on 24.05.2026.
//

extension UniverseModuleResources: UniverseNavigationControlling {

    public var navigation: any UniverseNavigationControlling {
        self
    }

    public func startNavigation(to name: String) {
        transferOrbitController.clearTransferOrbit()
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
