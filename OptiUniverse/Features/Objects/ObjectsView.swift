import BaseModule
import SwiftUI
import UniverseModule

/// The mounted objects scene and its overlays. The host owns navigation and resource preparation.
struct ObjectsView: View {
    let universeResources: UniverseModuleResources
    @Binding var objectsViewState: ObjectsViewState
    let isActive: Bool
    let selectedDestinationID: UUID?
    let mission: MissionFlightPlan?
    let allowsExpandedLayout: Bool
    let usesVerticalToolbar: Bool
    let onStartNavigation: (UUID) -> Void
    let onRetryTransfer: () -> Void
    let onRetryNavigation: () -> Void
    let onDoneNavigation: () -> Void

    @State private var universeViewportFrame: CGRect = .zero
    @State private var objectInfoPanelFrame: CGRect = .zero

    var body: some View {
        GeometryReader { container in
            let hasSidePanel = isObjectInfoPresented && AdaptiveLayoutPolicy.usesSidePanel(
                size: container.size, allowsExpandedLayout: allowsExpandedLayout
            )
            // Keep one renderer and one Info scroll view as the window and native bars change.
            ZStack {
                universeScene
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                if isActive, case .info(let entity) = objectsViewState {
                    makeInfoOverlay(entity: entity, viewport: container.size, hasSidePanel: hasSidePanel)
                }
            }
            .overlay {
                if isMissionNavigation, mission == .vostok1 {
                    vostokControlBackdrop
                }
            }
            .overlay(alignment: .bottom) {
                makeSceneControls(maxHeight: container.size.height * 0.45,
                                  usesVerticalToolbar: usesVerticalToolbar)
            }
            .coordinateSpace(name: "universeContent")
            .onChange(of: infoOverlayGeometry, initial: true) { _, _ in
                updateInfoFraming(hasSidePanel: hasSidePanel)
            }
            .onChange(of: hasSidePanel) { _, _ in updateInfoFraming(hasSidePanel: hasSidePanel) }
            .onChange(of: objectsViewState) { _, _ in updateInfoFraming(hasSidePanel: hasSidePanel) }
            .onChange(of: isActive) { _, _ in updateInfoFraming(hasSidePanel: hasSidePanel) }
        }
        .onDisappear {
            universeResources.setObjectInfoOverlayFraming(isPresented: false, bottomInset: 0, viewportHeight: 0)
        }
    }

    private var vostokControlBackdrop: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.black.opacity(0.82), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 155)
            Spacer(minLength: 0)
            LinearGradient(colors: [.clear, .black.opacity(0.86)], startPoint: .top, endPoint: .bottom)
                .frame(height: 175)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var universeScene: some View {
        // Expand the layout container as well as the renderer so projection uses the full scene.
        GeometryReader { _ in
            UniverseView(resources: universeResources,
                         isActive: isActive)
                .onGeometryChange(for: CGRect.self) { proxy in
                    proxy.frame(in: .named("universeContent"))
                } action: { universeViewportFrame = $0 }
                .opacity(isActive ? 1 : 0)
                .allowsHitTesting(isActive)
        }
        .ignoresSafeArea(.container,
                         edges: isActive ? .all : [])
    }

    private var infoOverlayGeometry: SceneOverlayGeometry {
        SceneOverlayGeometry(sceneFrame: universeViewportFrame, panelFrame: objectInfoPanelFrame)
    }

    private func updateInfoFraming(hasSidePanel: Bool) {
        let framesObject = isActive && isObjectInfoPresented && !hasSidePanel
        if !framesObject { objectInfoPanelFrame = .zero }
        universeResources.setObjectInfoOverlayFraming(
            isPresented: framesObject,
            bottomInset: framesObject ? infoOverlayGeometry.bottomInset : 0,
            viewportHeight: framesObject ? infoOverlayGeometry.viewportHeight : 0
        )
    }

    private func hideObjectInfoOverlay() {
        objectsViewState = .raw
    }

    private var isNavigation: Bool { isActive && objectsViewState == .navigation }
    private var isMissionNavigation: Bool { isNavigation && mission != nil }

    private var isObjectInfoPresented: Bool {
        if case .info = objectsViewState { return true }
        return false
    }

    private func makeInfoOverlay(entity: ObjectInfoViewEntity, viewport: CGSize,
                                 hasSidePanel: Bool) -> some View {
        ZStack(alignment: hasSidePanel ? .topTrailing : .bottom) {
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea(.container)
                .onTapGesture(perform: hideObjectInfoOverlay)
                .accessibilityHidden(true)

            ObjectInfoPanel(entity: entity,
                            availableWidth: hasSidePanel
                                ? AdaptiveLayoutPolicy.sidePanelWidth(availableWidth: viewport.width) : viewport.width,
                            availableHeight: viewport.height,
                            isSidePanel: hasSidePanel,
                            onDismiss: hideObjectInfoOverlay)
                .id(entity.id)
                .onGeometryChange(for: CGRect.self) { panel in
                    panel.frame(in: .named("universeContent"))
                } action: { objectInfoPanelFrame = hasSidePanel ? .zero : $0 }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    @ViewBuilder
    private func makeSceneControls(maxHeight: CGFloat, usesVerticalToolbar: Bool) -> some View {
        if isActive, objectsViewState != .raw, !isObjectInfoPresented {
            VStack(spacing: 8) {
                if isNavigation {
                    if isMissionNavigation {
                        missionEpilogue
                            .allowsHitTesting(false)
                        let snapshot = universeResources.navigation.navigationSnapshot
                        if snapshot.mission == .vostok1 {
                            makeNavigationRetryButton(snapshot: snapshot)
                            if snapshot.state == .completed {
                                Button("Done", systemImage: "checkmark") {
                                    onDoneNavigation()
                                }
                                .buttonStyle(NeonButtonStyle())
                            }
                        }
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
        let status = universeResources.navigation.navigationSnapshot.missionStatus
        let epilogue = status?.epilogueText
        return VStack {
            if let epilogue {
                Text(epilogue)
                    .font(Typography.navigationSubtitle)
                    .foregroundStyle(OptiColor.overlayTextPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(status?.mission == .vostok1 ? "vostokEpilogue" : "voyagerEpilogue")
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
                if !usesVerticalToolbar, let destinationID = selectedDestinationID {
                    makeStartNavigationButton(destinationID: destinationID)
                }
            }
        case .raw, .info, .navigation:
            EmptyView()
        }
    }
}
