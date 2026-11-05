#if DEBUG
import BaseModule
import SwiftUI
import UniverseModule
#if os(iOS)
import UIKit
#endif

struct ObjectsPreviewHost: View {
    @State private var model: ObjectsPreviewModel
    @State private var windowSize: CGSize = .zero
    @State private var isSceneMounted = false
    @State private var loadingAttempt = 0

    init(presentation: ObjectsPreviewModel.Presentation) {
        self.init(model: ObjectsPreviewModel(presentation: presentation))
    }

    init(model: ObjectsPreviewModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            ToolbarLayoutReader { usesVerticalToolbar in
                content(usesVerticalToolbar: usesVerticalToolbar)
                    .navigationTitle(model.environment.location)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { controls(usesVerticalToolbar: usesVerticalToolbar) }
                    .toolbarBackground(.hidden, for: .navigationBar, .bottomBar)
                    .toolbarVisibility(model.loadingState == .loaded ? .visible : .hidden, for: .navigationBar)
                    .toolbarVisibility(model.objectsViewState == .raw ? .visible : .hidden, for: .bottomBar)
            }
        }
        .background {
            Color.clear
                .onGeometryChange(for: CGSize.self) { $0.size } action: { windowSize = $0 }
                .ignoresSafeArea(.container)
        }
        .preferredColorScheme(.dark)
        .environment(model.environment)
        .task(id: loadingAttempt) { await model.prepare() }
    }

    @ViewBuilder
    private func content(usesVerticalToolbar: Bool) -> some View {
        switch model.loadingState {
        case .loading:
            LoadingScreenView()
        case .failed(let message):
            ContentUnavailableView {
                Label("Unable to Load Universe", systemImage: "exclamationmark.triangle")
            } description: {
                Text(message)
            } actions: {
                Button("Try Again") { loadingAttempt += 1 }
            }
        case .loaded:
            ObjectsView(universeResources: model.resources,
                        objectsViewState: $model.objectsViewState,
                        isActive: true,
                        selectedDestinationID: model.destination?.id,
                        mission: nil,
                        allowsExpandedLayout: allowsExpandedLayout,
                        usesVerticalToolbar: usesVerticalToolbar,
                        onStartNavigation: model.startNavigation,
                        onRetryTransfer: model.showRoute,
                        onRetryNavigation: startNavigation,
                        onDoneNavigation: model.doneNavigation)
                .background(OptiColor.screenBackground.ignoresSafeArea())
                .onAppear { isSceneMounted = true }
                // The next update runs after UniverseView.onAppear, whose selection sync clears transfers.
                .task(id: isSceneMounted) {
                    if isSceneMounted { model.sceneDidAppear() }
                }
                .animation(.default, value: model.objectsViewState)
                .animation(.default, value: model.resources.navigation.navigationSnapshot)
        }
    }

    private var allowsExpandedLayout: Bool {
        #if os(iOS)
        AdaptiveLayoutPolicy.allowsExpandedLayout(windowSize: windowSize,
                                                  isPad: UIDevice.current.userInterfaceIdiom == .pad)
        #else
        true
        #endif
    }

    private func startNavigation() {
        if let destination = model.destination { model.startNavigation(destinationID: destination.id) }
    }

    @ToolbarContentBuilder
    private func controls(usesVerticalToolbar: Bool) -> some ToolbarContent {
        if model.loadingState == .loaded {
            if model.objectsViewState == .orbit {
                if usesVerticalToolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Start navigation", systemImage: "paperplane", action: startNavigation)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close transfer preview", systemImage: "xmark", action: model.closeRoute)
                }
            } else if model.objectsViewState == .navigation {
                ToolbarItem(placement: .topBarTrailing) {
                    if model.resources.navigation.navigationSnapshot.state == .completed {
                        Button("Done", systemImage: "checkmark", action: model.doneNavigation)
                    } else {
                        Button("Cancel navigation", systemImage: "xmark", action: model.cancelNavigation)
                    }
                }
            } else if model.objectsViewState == .raw {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button("Object details", systemImage: "binoculars", action: model.showDetails)
                }
            }
        }
    }
}

#Preview("Objects · Scene") {
    ObjectsPreviewHost(presentation: .scene)
}

#Preview("Objects · Details") {
    ObjectsPreviewHost(presentation: .details)
}

#Preview("Objects · Transfer route") {
    ObjectsPreviewHost(presentation: .route)
}
#endif
