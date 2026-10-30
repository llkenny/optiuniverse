import SwiftUI
import BaseModule
import UniverseModule

extension RootContainerView {
    func makeContent(usesVerticalToolbar: Bool, onMissionSelected: @escaping (Mission) -> Void) -> some View {
        GeometryReader { container in
            let hasSidePanel = isObjectInfoPresented && AdaptiveLayoutPolicy.usesSidePanel(size: container.size)
            HStack(spacing: 0) {
                // This scene stays in the same structural position as the window and panels resize.
                ZStack {
                    universeScene

                    GeometryReader { viewport in
                        ZStack {
                            if appEnvironment.currentScreen == .home {
                                HomeView(onMissionSelected: onMissionSelected)
                                    .transition(.opacity)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(alignment: .bottom) {
                            if !hasSidePanel, case .info(let entity) = objectsViewState {
                                makeCompactInfoPanel(entity: entity, viewport: viewport.size)
                            }
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    makeSceneControls(maxHeight: container.size.height * 0.45,
                                      usesVerticalToolbar: usesVerticalToolbar)
                }

                if hasSidePanel, case .info(let entity) = objectsViewState {
                    ObjectInfoPanel(entity: entity, isSidePanel: true, onDismiss: hideObjectInfoOverlay)
                        .frame(width: AdaptiveLayoutPolicy.sidePanelWidth(availableWidth: container.size.width))
                        .background {
                            OptiColor.objectInfoSurface.ignoresSafeArea(.container)
                        }
                        .onAppear { clearObjectInfoFraming() }
                }
            }
            .coordinateSpace(name: "universeContent")
            .onChange(of: infoOverlayGeometry, initial: true) { _, _ in
                updateCompactInfoFraming(hasSidePanel: hasSidePanel)
            }
            .onChange(of: hasSidePanel) { _, isSidePanel in
                if isSidePanel { clearObjectInfoFraming() }
            }
        }
    }

    private var universeScene: some View {
        // Expand the layout container as well as the renderer so projection uses the full scene.
        GeometryReader { _ in
            UniverseView(resources: universeResources,
                         isActive: appEnvironment.currentScreen == .objects)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named("universeContent"))
                } action: { universeViewportFrame = $0 }
                .opacity(appEnvironment.currentScreen == .objects ? 1 : 0)
                .allowsHitTesting(appEnvironment.currentScreen == .objects)
        }
        .ignoresSafeArea(.container,
                         edges: appEnvironment.currentScreen == .objects ? .all : [])
    }

    private var infoOverlayGeometry: SceneOverlayGeometry {
        SceneOverlayGeometry(sceneFrame: universeViewportFrame, panelFrame: objectInfoPanelFrame)
    }

    private func updateCompactInfoFraming(hasSidePanel: Bool) {
        guard isObjectInfoPresented, !hasSidePanel else { return }
        universeResources.setObjectInfoOverlayFraming(isPresented: true,
                                                     bottomInset: infoOverlayGeometry.bottomInset,
                                                     viewportHeight: infoOverlayGeometry.viewportHeight)
    }

    private var isObjectInfoPresented: Bool {
        if case .info = objectsViewState { return true }
        return false
    }

    private func makeCompactInfoPanel(entity: ObjectInfoViewEntity, viewport: CGSize) -> some View {
        ObjectInfoPanel(entity: entity, onDismiss: hideObjectInfoOverlay)
            .frame(height: AdaptiveLayoutPolicy.bottomPanelHeight(viewportHeight: viewport.height))
            .onAppear { updateCompactInfoFraming(hasSidePanel: false) }
            .onGeometryChange(for: CGRect.self) { panel in
                panel.frame(in: .named("universeContent"))
            } action: { objectInfoPanelFrame = $0 }
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private func makeSceneControls(maxHeight: CGFloat, usesVerticalToolbar: Bool) -> some View {
        if appEnvironment.currentScreen == .objects, objectsViewState != .raw, !isObjectInfoPresented {
            VStack(spacing: 8) {
                if isNavigation {
                    if isMissionNavigation {
                        missionEpilogue
                            .allowsHitTesting(false)
                    } else {
                        makeNavigationRetryButton(snapshot: universeResources.navigation.navigationSnapshot)
                    }
                } else {
                    ViewThatFits(in: .vertical) {
                        sceneControlContent(usesVerticalToolbar: usesVerticalToolbar)
                            .fixedSize(horizontal: false, vertical: true)
                        ScrollView {
                            sceneControlContent(usesVerticalToolbar: usesVerticalToolbar)
                        }
                        .scrollBounceBehavior(.basedOnSize)
                    }
                    .frame(maxHeight: max(0, maxHeight), alignment: .bottom)
                }

                if objectsViewState == .navigation,
                   universeResources.simulationSnapshot.mode == .missionReplay ||
                    universeResources.simulationSnapshot.mode == .transferPreview {
                    SimulationTimeIndicatorView(snapshot: universeResources.simulationSnapshot)
                }
            }
            .frame(maxWidth: 640)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
    }

    private var missionEpilogue: some View {
        let epilogue = universeResources.navigation.navigationSnapshot.missionStatus?.epilogueText
        return VStack {
            if let epilogue {
                Text(epilogue)
                    .font(Typography.navigationSubtitle)
                    .foregroundStyle(OptiColor.overlayTextPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("voyagerEpilogue")
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.2), value: epilogue)
    }

    @ViewBuilder
    private func sceneControlContent(usesVerticalToolbar: Bool) -> some View {
        switch objectsViewState {
        case .orbit:
            VStack(spacing: 8) {
                makeTransferPreviewDetails()
                if !usesVerticalToolbar, let destinationID = appEnvironment.selectedDestinationID {
                    makeStartNavigationButton(destinationID: destinationID)
                }
            }
        case .raw, .info, .navigation:
            EmptyView()
        }
    }
}
