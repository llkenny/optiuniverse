//
//  MetalModuleResources+NavigationRenderStatePublishing.swift
//  MetalModule
//
//  Created by max on 24.05.2026.
//

extension MetalModuleResources: NavigationRenderStatePublishing {
    func publishNavigationSnapshot(_ snapshot: NavigationRouteSnapshot) {
        navigationSnapshot = snapshot
    }

    func publishNavigationCameraFollowEnabled(_ isEnabled: Bool) {
        navigationCameraFollowEnabled = isEnabled
    }
}
