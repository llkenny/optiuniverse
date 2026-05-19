//
//  RootContainerView.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI
import MetalModule
import BaseModule
import Foundation

struct RootContainerView: View {

    @Environment(AppEnvironment.self) var appEnvironment
    @State private var isDataLoaded: Bool = false
    @State var objectsViewState: ObjectsViewState = .raw

    private let meshProvider: MeshProvider
    let orbitRenderHandler: OrbitRenderHandler
    let navigationRenderHandler: NavigationRenderHandler

    init() {
        meshProvider = MeshProvider()
        orbitRenderHandler = OrbitRenderHandler()
        navigationRenderHandler = NavigationRenderHandler()
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
                            UniverseView(meshProvider: meshProvider,
                                         orbitRenderHandler: orbitRenderHandler,
                                         navigationRenderHandler: navigationRenderHandler)
                                .ignoresSafeArea(edges: .bottom)

                            switch objectsViewState {
                            case .raw:
                                if let selectedPlanet = appEnvironment.selectedPlanet {
                                    makeInfoButton(selectedPlanet: selectedPlanet)
                                }
                            case .orbit:
                                makeOrbitBackButton()
                                // TODO: The feature is not ready for production #246
//                                if let selectedPlanet = appEnvironment.selectedPlanet {
//                                    makeStartNavigationButton(destinationName: selectedPlanet)
//                                }
                            case .navigation:
                                makeNavigationControls(snapshot: navigationRenderHandler.navigationSnapshot)
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
        .animation(.default, value: navigationRenderHandler.navigationSnapshot)
        .onChange(of: navigationRenderHandler.navigationSnapshot.state) { _, newState in
            guard objectsViewState == .navigation,
                  newState == .cancelled else {
                return
            }

            objectsViewState = .raw
        }
        .task {
            await meshProvider.prepare()
            await appEnvironment.destinationsProvider.fetch()
            await appEnvironment.featuredObjectProvider.fetch()
            isDataLoaded = true
        }
        .overlay(alignment: .bottom) {
            if case .info(let selectedObjectInfo) = objectsViewState {
                makeInfoOverlay(entity: selectedObjectInfo)
            }
        }
        .animation(.default, value: objectsViewState)
    }
}

#Preview {
    RootContainerView()
        .environment(AppEnvironment())
}
