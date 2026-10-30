//
//  RootContainerView+Navigation.swift
//  OptiUniverse
//
//  Created by max on 12.05.2026.
//

import SwiftUI
import UniverseModule
import BaseModule

extension RootContainerView {

    var isNavigation: Bool {
        appEnvironment.currentScreen == .objects && objectsViewState == .navigation
    }

    var isMissionNavigation: Bool {
        isNavigation && missionFlowState != nil
    }

    @ViewBuilder
    func makeStartNavigationButton(destinationID: UUID) -> some View {
        Button {
            startNavigation(destinationID: destinationID)
        } label: {
            Image(systemName: "paperplane")
                .foregroundStyle(OptiColor.overlayTextPrimary)
                .font(Typography.button)
        }
        .buttonStyle(NeonButtonStyle())
        .accessibilityLabel("Start navigation")
    }

    func startNavigation(destinationID: UUID) {
        guard let destination = appEnvironment.destinationsProvider
            .destinations
            .first(where: { $0.id == destinationID }) else {
            return
        }

        universeResources.navigation.startNavigation(to: destination.object)
        missionFlowState = nil
        pendingMissionAdvance = nil
        objectsViewState = .navigation
    }

    @ViewBuilder
    func makeNavigationRetryButton(snapshot: NavigationRouteSnapshot) -> some View {
        if snapshot.state == .failed {
            Button {
                if let destination = snapshot.destinationName {
                    universeResources.navigation.startNavigation(to: destination)
                }
            } label: {
                Text("Retry")
                    .foregroundStyle(OptiColor.overlayTextPrimary)
                    .font(Typography.navigationControl)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NeonButtonStyle())
        }
    }

    func cancelNavigationAndDismissOverlays() {
        universeResources.navigation.cancelNavigation()
        missionFlowState = nil
        pendingMissionAdvance = nil
        objectsViewState = .raw
    }

    func navigationTitle(snapshot: NavigationRouteSnapshot) -> String {
        if snapshot.state == .completed {
            return "Arrived"
        }

        if let originName = snapshot.originName,
           let waypointName = snapshot.waypointName,
           let destinationName = snapshot.destinationName {
            return "Navigating \(originName) → \(waypointName) → \(destinationName)"
        }

        if let originName = snapshot.originName,
           let destinationName = snapshot.destinationName {
            return "Navigating \(originName) → \(destinationName)"
        }

        return "Navigating to \(snapshot.destinationName ?? "destination")"
    }

    func navigationSubtitle(snapshot: NavigationRouteSnapshot) -> String {
        if missionFlowState != nil {
            return missionNavigationSubtitle(snapshot: snapshot)
        }

        switch snapshot.state {
        case .running:
            if let duration = snapshot.physicalFlightDuration {
                let days = Int((duration / 86_400).rounded())
                return "\(days) day transfer · 30 s playback · ETA \(formatTime(snapshot.remainingTime))"
            }
            return "ETA \(formatTime(snapshot.remainingTime))"
        case .completed:
            return "Route complete"
        case .failed:
            return snapshot.failure?.rawValue ?? "Transfer unavailable"
        case .idle, .preparing, .cancelled:
            return ""
        }
    }

    func missionNavigationSubtitle(snapshot: NavigationRouteSnapshot) -> String {
        if snapshot.mission == .crew13 || snapshot.mission == .starshipFlight14 || snapshot.mission == .voyager1 {
            if snapshot.state == .failed { return "Mission unavailable" }
            guard let status = snapshot.missionStatus else { return "Preparing launch" }
            let phaseText = snapshot.mission == .starshipFlight14
                ? starshipPhaseText(status: status) : status.phase.rawValue
            return snapshot.state == .completed ? phaseText : "\(phaseText) · ETA \(formatTime(snapshot.remainingTime))"
        }
        let routeText = navigationRouteText(snapshot: snapshot)

        switch snapshot.state {
        case .preparing:
            return "Preparing \(routeText)"
        case .running:
            return "\(routeText) · ETA \(formatTime(snapshot.remainingTime))"
        case .completed:
            return routeText
        case .failed:
            return snapshot.failure?.rawValue ?? "Transfer unavailable"
        case .idle, .cancelled:
            return routeText
        }
    }

    private func starshipPhaseText(status: MissionNavigationStatus) -> String {
        if status.phase == .orbit {
            return "Orbit \(status.currentOrbit) of \(status.totalOrbits)"
        }
        if status.phase == .deployment {
            return "Deploying Starlinks · \(status.deployedSatelliteCount)/26"
        }
        return status.phase.rawValue
    }

    private func navigationRouteText(snapshot: NavigationRouteSnapshot) -> String {
        if let originName = snapshot.originName,
           let waypointName = snapshot.waypointName,
           let destinationName = snapshot.destinationName {
            return "\(originName) → \(waypointName) → \(destinationName)"
        }

        if let originName = snapshot.originName,
           let destinationName = snapshot.destinationName {
            return "\(originName) → \(destinationName)"
        }

        return "Earth → Moon → Earth"
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let clampedTime = max(Int(time.rounded(.up)), 0)
        let minutes = clampedTime / 60
        let seconds = clampedTime % 60

        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }

        return "\(seconds)s"
    }
}
