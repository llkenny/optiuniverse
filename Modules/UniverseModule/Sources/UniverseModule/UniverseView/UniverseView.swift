import RealityKit
import SwiftUI
internal import BaseModule

public struct UniverseView: View {
    #if os(visionOS)
    private static let immersiveControlsAttachmentID = "immersiveControls"
    #endif

    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var installationID = UUID()
    let resources: UniverseModuleResources
    let isActive: Bool
    private let immersiveControls: () -> AnyView

    public init(resources: UniverseModuleResources, isActive: Bool = true) {
        self.resources = resources
        self.isActive = isActive
        immersiveControls = { AnyView(EmptyView()) }
    }

    public init<ImmersiveControls: View>(
        resources: UniverseModuleResources,
        isActive: Bool = true,
        @ViewBuilder immersiveControls: @escaping () -> ImmersiveControls
    ) {
        self.resources = resources
        self.isActive = isActive
        self.immersiveControls = { AnyView(immersiveControls()) }
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                #if os(visionOS)
                RealityView { content, attachments in
                    resources.sceneCoordinator.install(
                        in: &content,
                        installationID: installationID
                    )
                    attachImmersiveControls(from: attachments, to: &content)
                } update: { content, attachments in
                    resources.sceneCoordinator.restoreInstallationIfNeeded(
                        in: &content,
                        installationID: installationID
                    )
                    attachImmersiveControls(from: attachments, to: &content)
                } attachments: {
                    Attachment(id: Self.immersiveControlsAttachmentID) {
                        immersiveControls()
                    }
                }
                #else
                RealityView { content in
                    resources.sceneCoordinator.install(
                        in: &content,
                        installationID: installationID
                    )
                    content.renderingEffects.customPostProcessing = .effect(
                        FilmicPostProcessEffect()
                    )
                } update: { content in
                    resources.sceneCoordinator.restoreInstallationIfNeeded(
                        in: &content,
                        installationID: installationID
                    )
                }
                .allowsHitTesting(false)

                CameraGestureView(resources: resources)
                #endif
            }
            .onAppear {
                resources.sceneCoordinator.setPresentationActive(isActive)
                resources.setViewportSize(geometry.size)
                synchronizeSelection()
            }
            .onChange(of: isActive) { _, isActive in
                resources.sceneCoordinator.setPresentationActive(isActive)
            }
            .onChange(of: geometry.size) { _, size in
                resources.setViewportSize(size)
            }
            .onChange(of: appEnvironment.selectedDestinationID) { _, _ in
                synchronizeSelection()
            }
            .onChange(of: appEnvironment.selectedPlanet) { _, _ in
                synchronizeSelection()
            }
            .onDisappear {
                resources.sceneCoordinator.setPresentationActive(false)
                resources.sceneCoordinator.dismantle(installationID: installationID)
            }
        }
    }

    #if os(visionOS)
    private func attachImmersiveControls(
        from attachments: RealityViewAttachments,
        to content: inout RealityViewContent
    ) {
        guard let controlsEntity = attachments.entity(for: Self.immersiveControlsAttachmentID) else {
            return
        }

        controlsEntity.name = "ImmersiveControlsAttachment"
        controlsEntity.position = SIMD3<Float>(0, 0.9, -0.85)
        controlsEntity.orientation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        controlsEntity.scale = SIMD3<Float>(repeating: 1)

        guard controlsEntity.parent == nil else { return }

        content.add(controlsEntity)
    }
    #endif

    private func synchronizeSelection() {
        #if os(visionOS)
        if let selectedDestinationID = appEnvironment.selectedDestinationID {
            resources.focusImmersiveDestination(
                identifiedBy: selectedDestinationID,
                destinations: appEnvironment.destinationsProvider.destinations
            )
        } else if let selectedPlanet = appEnvironment.selectedPlanet {
            resources.focusImmersivePlanet(named: selectedPlanet)
        } else {
            resources.clearImmersiveFocus()
        }
        #else
        if let selectedDestinationID = appEnvironment.selectedDestinationID {
            resources.followDestination(
                identifiedBy: selectedDestinationID,
                destinations: appEnvironment.destinationsProvider.destinations
            )
        } else if let selectedPlanet = appEnvironment.selectedPlanet {
            resources.followPlanet(named: selectedPlanet,
                                   surfaceLocation: nil)
        }
        #endif
    }
}
