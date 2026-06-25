#if os(visionOS)
import BaseModule
import SwiftUI
import UniverseModule

struct UniverseImmersiveView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    let resources: UniverseModuleResources

    @State private var previousDragTranslation: CGSize = .zero
    @State private var previousMagnification: CGFloat = 1

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
                let translation = CGSize(
                    width: value.translation.width - previousDragTranslation.width,
                    height: value.translation.height - previousDragTranslation.height
                )
                previousDragTranslation = value.translation

                if !resources.adjustImmersiveFocusRotation(translation: translation) {
                    resources.rotateCamera(
                        translation: translation,
                        velocity: velocity(for: value)
                    )
                }
            }
            .onEnded { _ in
                previousDragTranslation = .zero
            }
    }

    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let currentMagnification = CGFloat(value.magnification)
                let relativeScale = Float(currentMagnification / previousMagnification)
                previousMagnification = currentMagnification

                if !resources.adjustImmersiveFocusScale(by: relativeScale) {
                    resources.scaleCamera(
                        by: relativeScale,
                        velocity: 0
                    )
                }
            }
            .onEnded { _ in
                previousMagnification = 1
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
