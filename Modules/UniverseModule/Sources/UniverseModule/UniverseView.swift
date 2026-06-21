import RealityKit
import SwiftUI
internal import BaseModule

public struct UniverseView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var installationID = UUID()
    let resources: UniverseModuleResources
    let isActive: Bool

    public init(resources: UniverseModuleResources, isActive: Bool = true) {
        self.resources = resources
        self.isActive = isActive
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
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

    private func synchronizeSelection() {
        if let selectedDestinationID = appEnvironment.selectedDestinationID {
            resources.followDestination(
                identifiedBy: selectedDestinationID,
                destinations: appEnvironment.destinationsProvider.destinations
            )
        } else if let selectedPlanet = appEnvironment.selectedPlanet {
            resources.followPlanet(named: selectedPlanet,
                                   surfaceLocation: nil)
        }
    }
}
