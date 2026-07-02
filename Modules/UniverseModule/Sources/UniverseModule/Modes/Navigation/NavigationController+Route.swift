//
//  NavigationController+Route.swift
//  UniverseModule
//
//  Created by max on 25.05.2026.
//

import simd

extension NavigationController: UniverseNavigationControlling {
    func startNavigation(to name: String) {
        guard let snapshot = snapshotProvider.latestSnapshot,
              applyNavigation(named: name, snapshot: snapshot) else {
            pendingNavigationDestinationName = name
            return
        }

        pendingNavigationDestinationName = nil
    }

    func pauseNavigation() {
        navigationRouteCoordinator.pause()
    }

    func resumeNavigation() {
        navigationRouteCoordinator.resume()
    }

    func cancelNavigation() {
        navigationRouteCoordinator.cancel()
        pendingNavigationDestinationName = nil
    }

    func doneNavigation() {
        guard navigationRouteCoordinator.state == .completed else {
            cancelNavigation()
            return
        }

        navigationRouteCoordinator.cancel()
        pendingNavigationDestinationName = nil
    }

    func applyNavigation(named name: String,
                         snapshot: UniverseSceneSnapshot) -> Bool {
        guard navigationRouteCoordinator.start(destinationName: name,
                                               planets: planets,
                                               snapshot: snapshot),
              navigationRouteCoordinator.route != nil else {
            return true
        }

        return true
    }

    func refreshActiveRoute(snapshot: UniverseSceneSnapshot) {
        guard navigationRouteCoordinator.isNavigationActive,
              let route = navigationRouteCoordinator.activeRouteForRendering,
              let transferOrbit = makeTransferOrbit(destinationName: route.destinationName,
                                                    snapshot: snapshot),
              let destinationPosition = snapshot.worldPosition(
                ofPlanetNamed: transferOrbit.destinationName
              ) else {
            return
        }

        navigationRouteCoordinator.refresh(using: transferOrbit,
                                           destinationPosition: destinationPosition)
    }

    func makeTransferOrbit(destinationName: String,
                           snapshot: UniverseSceneSnapshot) -> HohmannTransferOrbit? {
        guard let sunPosition = snapshot.worldPosition(ofPlanetNamed: "Sun"),
              let earthPosition = snapshot.worldPosition(ofPlanetNamed: "Earth") else {
            return nil
        }

        return HohmannTransferOrbit.make(destinationName: destinationName,
                                         planets: planets,
                                         earthSunDirection: earthPosition - sunPosition,
                                         sunPosition: sunPosition)
    }
}
