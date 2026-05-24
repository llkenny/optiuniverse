//
//  NavigationRenderHandler.swift
//  MetalModule
//
//  Created by max on 12.05.2026.
//

@MainActor
protocol NavigationRenderStatePublishing: AnyObject {
    var navigationSnapshot: NavigationRouteSnapshot { get }
    var navigationCameraFollowEnabled: Bool { get }

    func publishNavigationSnapshot(_ snapshot: NavigationRouteSnapshot)
    func publishNavigationCameraFollowEnabled(_ isEnabled: Bool)
}
