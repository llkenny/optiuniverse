//
//  RootContainerView.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI
import UniverseModule
import BaseModule
import Foundation

struct RootContainerView: View {

    @Environment(AppEnvironment.self) var appEnvironment
    @State private var isDataLoaded: Bool = false
    @State var objectsViewState: ObjectsViewState = .raw
    @State var objectInfoOverlayPresentationID = UUID() // Force makeInfoOverlay recreation for animation stability
    @GestureState var objectInfoDragOffset: CGFloat = 0
    let universeResources: UniverseModuleResources

    init(universeResources: UniverseModuleResources) {
        self.universeResources = universeResources
    }

    var body: some View {
        ZStack {
            OptiColor.screenBackground
                .ignoresSafeArea()

            if isDataLoaded {
                VStack(spacing: 0) {
                    TopBarView()
                        .padding(.horizontal)
                        .padding(.bottom, 16)

                    switch appEnvironment.currentScreen {
                    case .home:
                        HomeView()
                    case .objects:
                        ZStack {
                            UniverseView(resources: universeResources)
                                .ignoresSafeArea(edges: .bottom)

                            switch objectsViewState {
                            case .raw:
                                if let selectedDestinationID = appEnvironment.selectedDestinationID {
                                    makeInfoButton(selectedDestinationID: selectedDestinationID)
                                }
                            case .orbit:
                                makeOrbitBackButton()
                                if let selectedDestinationID = appEnvironment.selectedDestinationID {
                                    makeStartNavigationButton(destinationID: selectedDestinationID)
                                }
                            case .navigation:
                                makeNavigationControls(snapshot: universeResources.navigation.navigationSnapshot)
                            default:
                                EmptyView()
                            }
                        }
                        .onAppear {
                            objectsViewState = .raw
                        }
                    }
                }
            } else {
                LoadingScreenView()
            }
        }
        .animation(.default, value: isDataLoaded)
        .animation(.default, value: appEnvironment.currentScreen)
        .animation(.default, value: universeResources.navigation.navigationSnapshot)
        .onChange(of: appEnvironment.currentScreen) { _, newScreen in
            guard newScreen == .home else { return }

            cancelObjectPresentationModes()
        }
        .onChange(of: appEnvironment.selectedDestinationID) { _, _ in
            objectsViewState = .raw
        }
        .onChange(of: universeResources.navigation.navigationSnapshot.state) { _, newState in
            guard objectsViewState == .navigation,
                  newState == .cancelled else {
                return
            }

            objectsViewState = .raw
        }
        .task {
            await universeResources.prepare()
            appEnvironment.destinationsProvider.fetch()
            appEnvironment.featuredObjectProvider.fetch()
            isDataLoaded = true
        }
        .overlay(alignment: .bottom) {
            if case .info(let selectedObjectInfo) = objectsViewState {
                makeInfoOverlay(entity: selectedObjectInfo)
                    .id(objectInfoOverlayPresentationID)
            }
        }
        .animation(.default, value: objectsViewState)
        .animation(.default, value: objectInfoOverlayPresentationID)
    }

    private func cancelObjectPresentationModes() {
        universeResources.setObjectInfoOverlayFraming(isPresented: false,
                                                   bottomInset: 0,
                                                   viewportHeight: 0)
        universeResources.transferOrbit.clearTransferOrbit()
        universeResources.navigation.cancelNavigation()
        objectsViewState = .raw
    }
}

#Preview {
    RootContainerView(universeResources: UniverseModuleFactory.makeResources())
        .environment(AppEnvironment())
}
