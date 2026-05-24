//
//  RootContainerView+Navigation.swift
//  OptiUniverse
//
//  Created by max on 12.05.2026.
//

import SwiftUI
import MetalModule

extension RootContainerView {

    @ViewBuilder
    func makeStartNavigationButton(destinationName: String) -> some View {
        Button {
            navigationController.startNavigation(to: destinationName)
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

            Toggle(isOn: navigationCameraFollowBinding) {
                Text("Follow marker")
                    .foregroundStyle(OptiColor.overlayTextSecondary)
                    .font(Typography.navigationControl)
            }
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

    private var navigationCameraFollowBinding: Binding<Bool> {
        Binding {
            navigationController.navigationCameraFollowEnabled
        } set: { isEnabled in
            navigationController.setNavigationCameraFollowEnabled(isEnabled)
        }
    }

    @ViewBuilder
    private func navigationActionControls(snapshot: NavigationRouteSnapshot) -> some View {
        HStack(spacing: 10) {
            switch snapshot.state {
            case .running:
                navigationControlButton(title: "Pause") {
                    navigationController.pauseNavigation()
                }
                navigationControlButton(title: "Cancel") {
                    cancelNavigationAndDismissOverlays()
                }
            case .paused:
                navigationControlButton(title: "Resume") {
                    navigationController.resumeNavigation()
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
        navigationController.cancelNavigation()
        objectsViewState = .raw
    }

    private func navigationTitle(snapshot: NavigationRouteSnapshot) -> String {
        if snapshot.state == .completed {
            return "Arrived"
        }

        return "Navigating to \(snapshot.destinationName ?? "destination")"
    }

    private func navigationSubtitle(snapshot: NavigationRouteSnapshot) -> String {
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
