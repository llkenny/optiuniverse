#if os(visionOS)
import BaseModule
import SwiftUI
import UniverseModule

struct VisionImmersiveControls<Resources: UniverseModuleResourcesProtocol>: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    let resources: Resources
    let selectedDestination: DestinationObject?
    let showObjectInfo: (DestinationObject) -> Void
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

            let preview = resources.transferOrbit.transferPreviewSnapshot
            switch preview.status {
            case .preparing:
                ProgressView("Calculating transfer…")
            case .ready:
                if let duration = preview.physicalFlightDuration {
                    Text("Two-body transfer · \(Int((duration / 86_400).rounded())) days · 30 s playback")
                }
                Button("Close orbit") { resources.transferOrbit.clearTransferOrbit() }
            case .failed(let failure):
                Text(failure.rawValue)
                Button("Retry transfer") {
                    if let destination = preview.destinationName { resources.transferOrbit.showTransferOrbit(to: destination) }
                }
                Button("Close orbit") { resources.transferOrbit.clearTransferOrbit() }
            case .inactive:
                EmptyView()
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
                    showObjectInfo(selectedDestination)
                } label: {
                    Label("Info", systemImage: "info.circle")
                }

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
                cancelButton
            case .failed:
                Button("Retry") { resources.navigation.startNavigation(to: selectedDestination.object) }
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
            if let duration = snapshot.physicalFlightDuration {
                return "\(Int((duration / 86_400).rounded())) day transfer · 30 s playback"
            }
            return "Navigating: \(Int((snapshot.progress * 100).rounded()))%"
        case .failed:
            return snapshot.failure?.rawValue ?? "Transfer unavailable"
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
        case .running, .completed:
            return true
        case .idle, .preparing, .cancelled, .failed:
            return false
        }
    }
}

#endif
