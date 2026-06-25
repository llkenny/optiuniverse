#if os(visionOS)
import BaseModule
import SwiftUI
import UniverseModule

struct VisionImmersiveControls: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    let resources: UniverseModuleResources
    let selectedDestination: DestinationObject?
    let exit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                destinationSummary
                Spacer(minLength: 18)
                routeControls
                Button(action: exit) {
                    Image(systemName: "xmark")
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Exit immersive universe")
            }

            if shouldShowProgress {
                ProgressView(value: Double(resources.navigation.navigationSnapshot.progress))
                    .tint(OptiColor.overlayTextPrimary)
            }
        }
        .padding(16)
        .frame(width: 620)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.panel))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.panel)
                .stroke(OptiColor.buttonBorder, lineWidth: 1)
        )
    }

    private var destinationSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(selectedDestination?.title ?? "Universe")
                .font(Typography.navigationTitle)
                .foregroundStyle(OptiColor.overlayTextPrimary)

            Text(subtitle)
                .font(Typography.navigationSubtitle)
                .foregroundStyle(OptiColor.overlayTextSecondary)
        }
    }

    @ViewBuilder
    private var routeControls: some View {
        if let selectedDestination {
            switch resources.navigation.navigationSnapshot.state {
            case .idle, .cancelled:
                Button {
                    resources.transferOrbit.showTransferOrbit(to: selectedDestination.object)
                } label: {
                    Label("Orbit", systemImage: "orbit")
                }
                .disabled(!selectedDestination.isNavigable)

                Button {
                    resources.navigation.startNavigation(to: selectedDestination.object)
                } label: {
                    Label("Route", systemImage: "paperplane")
                }
                .disabled(!selectedDestination.isNavigable)
            case .preparing:
                ProgressView()
            case .running:
                Button {
                    resources.navigation.pauseNavigation()
                } label: {
                    Label("Pause", systemImage: "pause")
                }

                cancelButton
            case .paused:
                Button {
                    resources.navigation.resumeNavigation()
                } label: {
                    Label("Resume", systemImage: "play")
                }

                cancelButton
            case .completed:
                Button {
                    resources.navigation.doneNavigation()
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
            }
        }
    }

    private var cancelButton: some View {
        Button {
            resources.navigation.cancelNavigation()
        } label: {
            Label("Cancel", systemImage: "stop")
        }
    }

    private var subtitle: String {
        let snapshot = resources.navigation.navigationSnapshot

        switch snapshot.state {
        case .running:
            return "Navigating: \(Int((snapshot.progress * 100).rounded()))%"
        case .paused:
            return "Navigation paused"
        case .completed:
            return "Route complete"
        case .preparing:
            return "Preparing route"
        case .idle, .cancelled:
            return selectedDestination?.subtitle ?? appEnvironment.location
        }
    }

    private var shouldShowProgress: Bool {
        switch resources.navigation.navigationSnapshot.state {
        case .running, .paused, .completed:
            return true
        case .idle, .preparing, .cancelled:
            return false
        }
    }
}
#endif
