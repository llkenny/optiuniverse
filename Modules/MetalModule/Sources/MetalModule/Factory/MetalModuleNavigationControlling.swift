//
//  MetalModuleNavigationControlling.swift
//  MetalModule
//
//  Created by max on 24.05.2026.
//

@MainActor
public protocol MetalModuleNavigationControlling: AnyObject {
    var navigationSnapshot: NavigationRouteSnapshot { get }
    var navigationCameraFollowEnabled: Bool { get }

    func startNavigation(to destinationName: String)
    func pauseNavigation()
    func resumeNavigation()
    func cancelNavigation()
    func doneNavigation()
    func setNavigationCameraFollowEnabled(_ isEnabled: Bool)
}
