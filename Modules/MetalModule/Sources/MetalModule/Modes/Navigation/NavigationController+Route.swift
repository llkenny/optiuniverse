//
//  NavigationController+Route.swift
//  MetalModule
//
//  Created by max on 25.05.2026.
//

import simd

extension NavigationController: MetalModuleNavigationControlling {
    func startNavigation(to name: String) {
        guard let snapshot = snapshotProvider.latestSnapshot,
              applyNavigation(named: name, snapshot: snapshot) else {
            pendingNavigationDestinationName = name
            cameraTransition = nil
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
        cancelNavigation(followDestination: true)
    }

    func cancelNavigation(followDestination: Bool) {
        let destinationName = navigationRouteCoordinator.activeRouteForRendering?.destinationName
        ?? navigationStatePublisher.navigationSnapshot.destinationName

        navigationRouteCoordinator.cancel()
        cameraCoordinator.endNavigationCameraControl(routeID: nil)
        resetNavigationArrivalTransition()
        pendingNavigationDestinationName = nil
        cameraTransition = nil
        navigationCameraFollowEnabled = true
        navigationStatePublisher.publishNavigationCameraFollowEnabled(true)

        guard followDestination,
              let destinationName else { return }
        followPlanet?(destinationName)
    }

    func doneNavigation() {
        guard navigationRouteCoordinator.state == .completed else {
            cancelNavigation()
            return
        }

        let destinationName = navigationRouteCoordinator.activeRouteForRendering?.destinationName
        ?? navigationStatePublisher.navigationSnapshot.destinationName

        navigationRouteCoordinator.cancel()
        cameraCoordinator.endNavigationCameraControl(routeID: nil)
        resetNavigationArrivalTransition()
        pendingNavigationDestinationName = nil
        cameraTransition = nil
        navigationCameraFollowEnabled = true
        navigationStatePublisher.publishNavigationCameraFollowEnabled(true)

        guard let destinationName else { return }
        followPlanet?(destinationName)
    }

    func setNavigationCameraFollowEnabled(_ isEnabled: Bool) {
        navigationCameraFollowEnabled = isEnabled
        navigationStatePublisher.publishNavigationCameraFollowEnabled(isEnabled)
        if isEnabled {
            cameraTransition = nil
        } else if let route = navigationRouteCoordinator.activeRouteForRendering,
                  let snapshot = snapshotProvider.latestSnapshot {
            startNavigationOverviewAnimation(route: route, snapshot: snapshot)
        }
    }

    func applyNavigation(named name: String,
                         snapshot: PreparedRenderSnapshot) -> Bool {
        resetNavigationArrivalTransition()

        guard navigationRouteCoordinator.start(destinationName: name,
                                               planets: planets,
                                               snapshot: snapshot),
              let route = navigationRouteCoordinator.route else {
            cameraCoordinator.endNavigationCameraControl(routeID: nil)
            followPlanet?(name)
            return true
        }

        if navigationCameraFollowEnabled {
            cameraTransition = nil
            captureNavigationCameraTrailingOffset(route: route, snapshot: snapshot)
            updateNavigationFollowCamera(snapshot: snapshot)
        } else {
            startNavigationOverviewAnimation(route: route,
                                             snapshot: snapshot)
        }
        return true
    }

    func refreshActiveRoute(snapshot: PreparedRenderSnapshot) {
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
                           snapshot: PreparedRenderSnapshot) -> HohmannTransferOrbit? {
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
