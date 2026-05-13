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
            navigationRenderHandler.startNavigation(to: destinationName)
            objectsViewState = .navigation
        } label: {
            Text("🚀")
                .foregroundStyle(.neonTextPrimary)
                .font(.system(size: 16))
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
                        .foregroundStyle(.neonTextPrimary)
                        .font(.system(size: 15, weight: .semibold))

                    Text(navigationSubtitle(snapshot: snapshot))
                        .foregroundStyle(.neonTextSecondary)
                        .font(.system(size: 12))
                }

                Spacer(minLength: 18)

                Text("\(Int((snapshot.progress * 100).rounded()))%")
                    .foregroundStyle(.neonTextPrimary)
                    .font(.system(size: 14, weight: .medium))
            }

            ProgressView(value: Double(snapshot.progress))
                .tint(.neonTextPrimary)

            Toggle(isOn: navigationCameraFollowBinding) {
                Text("Follow marker")
                    .foregroundStyle(.neonTextSecondary)
                    .font(.system(size: 13, weight: .medium))
            }
            .tint(.neonTextPrimary)

            navigationActionControls(snapshot: snapshot)
        }
        .padding(14)
        .background(.neonSectionFill.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.neonButtonBorder, lineWidth: 1)
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
            navigationRenderHandler.navigationCameraFollowEnabled
        } set: { isEnabled in
            navigationRenderHandler.setNavigationCameraFollowEnabled(isEnabled)
        }
    }

    @ViewBuilder
    private func navigationActionControls(snapshot: NavigationRouteSnapshot) -> some View {
        HStack(spacing: 10) {
            switch snapshot.state {
            case .running:
                navigationControlButton(title: "Pause") {
                    navigationRenderHandler.pauseNavigation()
                }
                navigationControlButton(title: "Cancel") {
                    cancelNavigationAndDismissOverlays()
                }
            case .paused:
                navigationControlButton(title: "Resume") {
                    navigationRenderHandler.resumeNavigation()
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
                .foregroundStyle(.neonTextPrimary)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(NeonButtonStyle())
    }

    private func cancelNavigationAndDismissOverlays() {
        navigationRenderHandler.cancelNavigation()
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
