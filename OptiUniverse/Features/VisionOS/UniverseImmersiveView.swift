#if os(visionOS)
import BaseModule
import SwiftUI
import UniverseModule

struct UniverseImmersiveView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    let resources: UniverseModuleResources

    var body: some View {
        UniverseView(
            resources: resources,
            isActive: appEnvironment.isUniverseImmersivePresented
        )
        .gesture(rotateGesture)
        .simultaneousGesture(zoomGesture)
        .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .bottom) {
            VisionImmersiveControls(
                resources: resources,
                selectedDestination: selectedDestination,
                exit: {
                    Task {
                        await exitImmersiveSpace()
                    }
                }
            )
            .environment(appEnvironment)
        }
        .onAppear {
            appEnvironment.isUniverseImmersivePresented = true
        }
        .onDisappear {
            appEnvironment.isUniverseImmersivePresented = false
        }
    }

    private var selectedDestination: DestinationObject? {
        guard let selectedDestinationID = appEnvironment.selectedDestinationID else {
            return nil
        }

        return appEnvironment.destinationsProvider.destinations.first {
            $0.id == selectedDestinationID
        }
    }

    private var rotateGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                resources.rotateCamera(
                    translation: value.translation,
                    velocity: velocity(for: value)
                )
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                resources.scaleCamera(by: Float(value.magnification))
            }
    }

    private func velocity(for value: DragGesture.Value) -> CGSize {
        let predicted = value.predictedEndTranslation
        let current = value.translation

        return CGSize(
            width: predicted.width - current.width,
            height: predicted.height - current.height
        )
    }

    private func exitImmersiveSpace() async {
        resources.transferOrbit.clearTransferOrbit()
        resources.navigation.cancelNavigation()
        await dismissImmersiveSpace()
        appEnvironment.isUniverseImmersivePresented = false
        appEnvironment.currentScreen = .home
    }
}
#endif
