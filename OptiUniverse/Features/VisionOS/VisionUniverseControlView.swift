#if os(visionOS)
import BaseModule
import SwiftUI
import UniverseModule

struct VisionUniverseControlView: View {
    private enum LoadingState: Equatable {
        case loading
        case loaded
        case failed(String)
    }

    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    let universeResources: UniverseModuleResources

    @State private var loadingState: LoadingState = .loading
    @State private var loadingAttempt = 0
    @State private var isOpeningImmersiveSpace = false

    var body: some View {
        ZStack {
            OptiColor.screenBackground
                .ignoresSafeArea()

            switch loadingState {
            case .loading:
                LoadingScreenView()
            case .failed(let message):
                VisionUniverseLoadingFailureView(message: message) {
                    loadingState = .loading
                    loadingAttempt += 1
                }
            case .loaded:
                loadedContent
            }
        }
        .task(id: loadingAttempt) {
            await prepareUniverse()
        }
        .onChange(of: appEnvironment.selectedDestinationID) { _, newValue in
            guard newValue != nil else { return }

            Task {
                await openUniverseIfNeeded()
            }
        }
    }

    private var loadedContent: some View {
        ZStack(alignment: .bottom) {
            HomeView()

            VStack(spacing: 10) {
                Text(controlTitle)
                    .font(Typography.navigationTitle)
                    .foregroundStyle(OptiColor.overlayTextPrimary)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Button {
                        Task {
                            await openUniverseIfNeeded()
                        }
                    } label: {
                        Label("Enter Universe", systemImage: "visionpro")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(appEnvironment.selectedDestinationID == nil ||
                              appEnvironment.isUniverseImmersivePresented ||
                              isOpeningImmersiveSpace)

                    Button {
                        Task {
                            await dismissUniverse()
                        }
                    } label: {
                        Label("Exit", systemImage: "xmark")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!appEnvironment.isUniverseImmersivePresented)
                }
                .font(Typography.navigationControl)
            }
            .padding(16)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.panel))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.panel)
                    .stroke(OptiColor.buttonBorder, lineWidth: 1)
            )
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
    }

    private var controlTitle: String {
        if appEnvironment.isUniverseImmersivePresented {
            return appEnvironment.location
        }

        if let selectedPlanet = appEnvironment.selectedPlanet {
            return "Ready for \(selectedPlanet)"
        }

        return "Choose a destination"
    }

    private func prepareUniverse() async {
        do {
            try await universeResources.prepare()
            try Task.checkCancellation()
            appEnvironment.destinationsProvider.fetch()
            appEnvironment.featuredObjectProvider.fetch()
            loadingState = .loaded
        } catch is CancellationError {
            return
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }

    private func openUniverseIfNeeded() async {
        guard !appEnvironment.isUniverseImmersivePresented,
              !isOpeningImmersiveSpace else {
            return
        }

        isOpeningImmersiveSpace = true
        let result = await openImmersiveSpace(id: VisionSceneID.universeImmersiveSpace)
        isOpeningImmersiveSpace = false

        if result == .opened {
            appEnvironment.isUniverseImmersivePresented = true
            appEnvironment.currentScreen = .objects
        }
    }

    private func dismissUniverse() async {
        guard appEnvironment.isUniverseImmersivePresented else { return }

        universeResources.transferOrbit.clearTransferOrbit()
        universeResources.navigation.cancelNavigation()
        await dismissImmersiveSpace()
        appEnvironment.isUniverseImmersivePresented = false
        appEnvironment.currentScreen = .home
    }
}

private struct VisionUniverseLoadingFailureView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(OptiColor.overlayTextPrimary)

            Text("Unable to Load Universe")
                .font(Typography.screenTitle)
                .foregroundStyle(OptiColor.textPrimary)

            Text(message)
                .font(Typography.overlayBody)
                .foregroundStyle(OptiColor.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: retry) {
                NeonButtonView(title: "Try Again")
            }
            .buttonStyle(NeonButtonStyle())
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(OptiColor.screenBackground)
    }
}
#endif
