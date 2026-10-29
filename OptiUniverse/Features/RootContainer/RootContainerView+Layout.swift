import SwiftUI
import BaseModule
import UniverseModule

extension RootContainerView {
    func makeContent(onMissionSelected: @escaping (Mission) -> Void) -> some View {
        GeometryReader { container in
            let hasSidePanel = isObjectInfoPresented && AdaptiveLayoutPolicy.usesSidePanel(size: container.size)
            HStack(spacing: 0) {
                // This scene stays in the same structural position as the window and panels resize.
                GeometryReader { viewport in
                    ZStack {
                        UniverseView(resources: universeResources,
                                     isActive: appEnvironment.currentScreen == .objects)
                            .opacity(appEnvironment.currentScreen == .objects ? 1 : 0)
                            .allowsHitTesting(appEnvironment.currentScreen == .objects)

                        if appEnvironment.currentScreen == .home {
                            HomeView(onMissionSelected: onMissionSelected)
                                .transition(.opacity)
                        } else {
                            SimulationTimeIndicatorView(snapshot: universeResources.simulationSnapshot)
                                .padding(12)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if !hasSidePanel, case .info(let entity) = objectsViewState {
                            makeCompactInfoPanel(entity: entity, viewport: viewport.size)
                        }
                    }
                }

                if hasSidePanel, case .info(let entity) = objectsViewState {
                    ObjectInfoPanel(entity: entity, isSidePanel: true, onDismiss: hideObjectInfoOverlay)
                        .frame(width: AdaptiveLayoutPolicy.sidePanelWidth(availableWidth: container.size.width))
                        .onAppear { clearObjectInfoFraming() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                makeSceneControls(maxHeight: container.size.height * 0.45)
            }
            .onChange(of: hasSidePanel) { _, isSidePanel in
                if isSidePanel { clearObjectInfoFraming() }
            }
        }
    }

    private var isObjectInfoPresented: Bool {
        if case .info = objectsViewState { return true }
        return false
    }

    private func makeCompactInfoPanel(entity: ObjectInfoViewEntity, viewport: CGSize) -> some View {
        ObjectInfoPanel(entity: entity, onDismiss: hideObjectInfoOverlay)
            .frame(height: AdaptiveLayoutPolicy.bottomPanelHeight(viewportHeight: viewport.height))
            // Observe the viewport as well as panel height: a resize can leave the panel's size unchanged.
            .onGeometryChange(for: ObjectInfoPanelMetrics.self) { panel in
                ObjectInfoPanelMetrics(panelHeight: panel.size.height, viewportHeight: viewport.height)
            } action: { metrics in
                universeResources.setObjectInfoOverlayFraming(isPresented: true,
                                                             bottomInset: metrics.panelHeight,
                                                             viewportHeight: metrics.viewportHeight)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private func makeSceneControls(maxHeight: CGFloat) -> some View {
        if appEnvironment.currentScreen == .objects, objectsViewState != .raw, !isObjectInfoPresented {
            ScrollView {
                switch objectsViewState {
                case .navigation:
                    makeNavigationControls(snapshot: universeResources.navigation.navigationSnapshot)
                case .orbit:
                    VStack(spacing: 8) {
                        makeOrbitBackButton()
                        if let destinationID = appEnvironment.selectedDestinationID {
                            makeStartNavigationButton(destinationID: destinationID)
                        }
                    }
                case .raw, .info:
                    EmptyView()
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 640, maxHeight: max(0, maxHeight))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }
}

private nonisolated struct ObjectInfoPanelMetrics: Equatable {
    let panelHeight: CGFloat
    let viewportHeight: CGFloat
}
