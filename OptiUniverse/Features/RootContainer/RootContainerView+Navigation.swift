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

    @ViewBuilder
    func makeStartNavigationButton(destinationID: UUID) -> some View {
        Button {
            guard let destination = appEnvironment.destinationsProvider
                .destinations
                .first(where: { $0.id == destinationID }) else {
                return
            }

            universeResources.navigation.startNavigation(to: destination.object)
            missionFlowState = nil
            pendingMissionAdvance = nil
            objectsViewState = .navigation
        } label: {
            Image(systemName: "paperplane")
                .foregroundStyle(OptiColor.overlayTextPrimary)
                .font(Typography.button)
        }
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .bottom)
        .buttonStyle(NeonButtonStyle())
    }

    @ViewBuilder
    func makeNavigationControls(snapshot: NavigationRouteSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(navigationTitle(snapshot: snapshot))
                        .foregroundStyle(OptiColor.overlayTextPrimary)
                        .font(Typography.navigationTitle)

                    Text(navigationSubtitle(snapshot: snapshot))
                        .foregroundStyle(OptiColor.overlayTextSecondary)
                        .font(Typography.navigationSubtitle)
                }

                Spacer(minLength: 18)

                Text("\(Int((snapshot.progress * 100).rounded()))%")
                    .foregroundStyle(OptiColor.overlayTextPrimary)
                    .font(Typography.navigationMeta)
            }

            ProgressView(value: Double(snapshot.progress))
                .tint(OptiColor.overlayTextPrimary)

            navigationActionControls(snapshot: snapshot)
        }
        .padding(14)
        .background(OptiColor.overlaySurface.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.panel))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.panel)
                .stroke(OptiColor.buttonBorder, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity,
               maxHeight: .infinity,
               alignment: .bottom)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private func navigationActionControls(snapshot: NavigationRouteSnapshot) -> some View {
        HStack(spacing: 10) {
            switch snapshot.state {
            case .running:
                navigationControlButton(title: "Pause") {
                    universeResources.navigation.pauseNavigation()
                }
                navigationControlButton(title: "Cancel") {
                    cancelNavigationAndDismissOverlays()
                }
            case .paused:
                navigationControlButton(title: "Resume") {
                    universeResources.navigation.resumeNavigation()
                }
                navigationControlButton(title: "Cancel") {
                    cancelNavigationAndDismissOverlays()
                }
            case .idle, .preparing, .completed, .cancelled:
                EmptyView()
            }
        }
    }

    private func navigationControlButton(title: String,
                                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .foregroundStyle(OptiColor.overlayTextPrimary)
                .font(Typography.navigationControl)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(NeonButtonStyle())
    }

    private func cancelNavigationAndDismissOverlays() {
        universeResources.navigation.cancelNavigation()
        missionFlowState = nil
        pendingMissionAdvance = nil
        objectsViewState = .raw
    }

    private func navigationTitle(snapshot: NavigationRouteSnapshot) -> String {
        if let missionFlowState {
            if snapshot.state == .completed {
                return "\(missionFlowState.mission.title) complete"
            }

            return missionFlowState.mission.title
        }

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

    private func navigationSubtitle(snapshot: NavigationRouteSnapshot) -> String {
        if missionFlowState != nil {
            return missionNavigationSubtitle(snapshot: snapshot)
        }

        switch snapshot.state {
        case .running:
            return "ETA \(formatTime(snapshot.remainingTime))"
        case .paused:
            return "Paused"
        case .completed:
            return "Route complete"
        case .idle, .preparing, .cancelled:
            return ""
        }
    }

    private func missionNavigationSubtitle(snapshot: NavigationRouteSnapshot) -> String {
        let routeText = navigationRouteText(snapshot: snapshot)

        switch snapshot.state {
        case .preparing:
            return "Preparing \(routeText)"
        case .running:
            return "\(routeText) · ETA \(formatTime(snapshot.remainingTime))"
        case .paused:
            return "\(routeText) · Paused"
        case .completed:
            return routeText
        case .idle, .cancelled:
            return routeText
        }
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
