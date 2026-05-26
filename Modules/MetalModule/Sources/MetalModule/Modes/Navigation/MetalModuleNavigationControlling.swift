//
//  MetalModuleNavigationControlling.swift
//  MetalModule
//
//  Created by max on 24.05.2026.
//

@MainActor
// TODO: Rename to NavigationControllerProtocol
public protocol MetalModuleNavigationControlling: AnyObject {
    var navigationSnapshot: NavigationRouteSnapshot { get }
    var navigationCameraFollowEnabled: Bool { get }

    func startNavigation(to name: String)
    func pauseNavigation()
    func resumeNavigation()
    func cancelNavigation()
    func doneNavigation()
    func setNavigationCameraFollowEnabled(_ isEnabled: Bool)
}
