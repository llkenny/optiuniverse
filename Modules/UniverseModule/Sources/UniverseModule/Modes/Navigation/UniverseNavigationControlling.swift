//
//  UniverseNavigationControlling.swift
//  UniverseModule
//
//  Created by max on 24.05.2026.
//

@MainActor
/// Public command surface for route navigation.
///
/// This protocol is necessary to keep `UniverseModuleResources.navigation` stable while the concrete
/// navigation owner can evolve internally. `NavigationController` implements it, and callers use it for
/// lifecycle commands and read-only navigation state.
///
/// Ownership:
/// - Does not own route, camera, or render state.
/// - Exposes immutable route snapshots.
/// - Keeps transfer-orbit preview out of the navigation API; that remains a separate renderer-facing
///   control surface.
public protocol UniverseNavigationControlling: AnyObject {
    var navigationSnapshot: NavigationRouteSnapshot { get }

    func startNavigation(from originName: String, via waypointName: String?, to destinationName: String)
    func startNavigation(from originName: String, to destinationName: String)
    func startNavigation(to name: String)
    func pauseNavigation()
    func resumeNavigation()
    func cancelNavigation()
    func doneNavigation()
}

public extension UniverseNavigationControlling {
    func startNavigation(from originName: String, to destinationName: String) {
        startNavigation(from: originName, via: nil, to: destinationName)
    }

    func startNavigation(to name: String) {
        startNavigation(from: "Earth", to: name)
    }
}
