import RealityKit
import SwiftUI
internal import BaseModule

public struct UniverseView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var installationID = UUID()
    let resources: UniverseModuleResources

    public init(resources: UniverseModuleResources) {
        self.resources = resources
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
                resources.setViewportSize(geometry.size)
                synchronizeSelection()
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
