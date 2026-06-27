#if os(visionOS)
import BaseModule
import SwiftUI
import UniverseModule

struct UniverseImmersiveView<Resources: UniverseModuleResourcesProtocol, UniverseContent: View>: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    let resources: Resources
    private let universeContent: (Bool) -> UniverseContent

    @State private var previousDragTranslation: CGSize = .zero
    @State private var previousMagnification: CGFloat = 1
    @State private var presentedObjectInfo: ObjectInfoViewEntity?

    init(resources: UniverseModuleResources) where Resources == UniverseModuleResources,
                                                   UniverseContent == UniverseView {
        self.resources = resources
        universeContent = { isActive in
            UniverseView(resources: resources, isActive: isActive)
        }
    }

    init(resources: Resources,
         @ViewBuilder universeContent: @escaping (Bool) -> UniverseContent) {
        self.resources = resources
        self.universeContent = universeContent
    }

    var body: some View {
        universeContent(appEnvironment.isUniverseImmersivePresented)
        .gesture(rotateGesture)
        .simultaneousGesture(zoomGesture)
        .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .bottom) {
            VisionImmersiveControls(
                resources: resources,
                selectedDestination: selectedDestination,
                showObjectInfo: { destination in
                    presentObjectInfo(for: destination)
                },
                exit: {
                    Task {
                        await exitImmersiveSpace()
                    }
                }
            )
            .environment(appEnvironment)
        }
        .ornament(attachmentAnchor: .scene(.trailing), contentAlignment: .trailing) {
            if let presentedObjectInfo {
                objectInfoOrnament(entity: presentedObjectInfo)
            }
        }
        .onAppear {
            appEnvironment.isUniverseImmersivePresented = true
        }
        .onDisappear {
            appEnvironment.isUniverseImmersivePresented = false
        }
        .onChange(of: appEnvironment.selectedDestinationID) { _, _ in
            presentedObjectInfo = nil
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

    private func objectInfoOrnament(entity: ObjectInfoViewEntity) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button {
                    presentedObjectInfo = nil
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Close object info")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            ScrollView {
                ObjectInfoView(entity: entity)
                    .padding(.bottom, 16)
            }
        }
        .frame(width: 440)
        .frame(maxHeight: 620)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.panel))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.panel)
                .stroke(OptiColor.buttonBorder, lineWidth: 1)
        )
    }

    private func presentObjectInfo(for destination: DestinationObject) {
        let details = destination.details.map {
            ObjectInfoDetailCardEntity(title: $0.title,
                                       value: $0.value,
                                       dimension: $0.dimension)
        }
        let orbitInfo = destination.orbitInfo.map {
            ObjectInfoOrbitView.Model(
                description: $0.description,
                properties: [
                    .axis: $0.properties.axis,
                    .eccentricity: $0.properties.eccentricity,
                    .inclination: $0.properties.inclination
                ]
            )
        }

        presentedObjectInfo = ObjectInfoViewEntity(
            id: destination.id,
            imageName: destination.infoImageName,
            title: destination.title,
            subtitle: destination.subtitle,
            description: destination.description,
            details: details,
            navigationButtonTitle: "🎯 Route",
            isNavigable: destination.isNavigable,
            orbitInfo: orbitInfo,
            navigationButtonAction: {
                presentedObjectInfo = nil
                resources.transferOrbit.showTransferOrbit(to: destination.object)
            }
        )
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
        presentedObjectInfo = nil
        resources.transferOrbit.clearTransferOrbit()
        resources.navigation.cancelNavigation()
        await dismissImmersiveSpace()
        appEnvironment.isUniverseImmersivePresented = false
        appEnvironment.currentScreen = .home
    }
}

#endif
