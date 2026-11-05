import SwiftUI
import UniverseModule

extension ObjectsView {

    @ViewBuilder
    func makeStartNavigationButton(destinationID: UUID) -> some View {
        Button {
            onStartNavigation(destinationID)
        } label: {
            Image(systemName: "paperplane")
                .foregroundStyle(OptiColor.overlayTextPrimary)
                .font(Typography.button)
        }
        .buttonStyle(NeonButtonStyle())
        .accessibilityLabel("Start navigation")
    }

    @ViewBuilder
    func makeNavigationRetryButton(snapshot: NavigationRouteSnapshot) -> some View {
        if snapshot.state == .failed {
            Button {
                onRetryNavigation()
            } label: {
                Text("Retry")
                    .foregroundStyle(OptiColor.overlayTextPrimary)
                    .font(Typography.navigationControl)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(NeonButtonStyle())
        }
    }

    @ViewBuilder
    func makeTransferPreviewDetails() -> some View {
        VStack(alignment: .trailing, spacing: 12) {
            let preview = universeResources.transferPreviewSnapshot
            switch preview.status {
            case .preparing:
                ProgressView("Calculating transfer…")
            case .ready:
                if let duration = preview.physicalFlightDuration {
                    Text("Two-body transfer · \(Int((duration / 86_400).rounded())) days · 30 s playback")
                        .font(Typography.navigationMeta)
                }
                if let label = preview.partialOrbitLabel {
                    Text(label).font(Typography.navigationMeta)
                }
            case .failed(let failure):
                Text(failure.rawValue).font(Typography.navigationMeta)
                Button("Retry") {
                    onRetryTransfer()
                }
            case .inactive:
                EmptyView()
            }
        }
        .foregroundStyle(OptiColor.overlayTextPrimary)
        .padding()
        .buttonStyle(NeonButtonStyle())
    }
}
