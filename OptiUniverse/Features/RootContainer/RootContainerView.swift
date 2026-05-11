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
    @Bindable private(set) var metalProvider: MetalProvider
    @State private var isDataLoaded: Bool = false
    @State var objectsViewState: ObjectsViewState = .raw

    private let modelLoader: ModelLoader

    init() {
        modelLoader = ModelLoader(resourceName: "high_resolution_solar_system")
        metalProvider = MetalProvider(modelLoader: modelLoader)
    }

    var body: some View {
        ZStack {
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
                            UniverseView(metalProvider: metalProvider)
                                .ignoresSafeArea(edges: .bottom)

                            if case.orbit(let summary) = objectsViewState {
                                makeOrbitSummary(summary: summary)
                                makeOrbitBackButton()
                            }

                            if let selectedPlanet = appEnvironment.selectedPlanet,
                               case .raw = objectsViewState {
                                makeInfoButton(selectedPlanet: selectedPlanet)
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
        .animation(.default, value: metalProvider.transferOrbitSummary)
        .task {
            await metalProvider.prepare()
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
