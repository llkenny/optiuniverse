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

    @Environment(AppEnvironment.self) private var appEnvironment
    @Bindable private var metalProvider: MetalProvider

    private let modelLoader: ModelLoader

    init() {
        modelLoader = ModelLoader(resourceName: "high_resolution_solar_system")
        metalProvider = MetalProvider(modelLoader: modelLoader)
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBarView()
                .padding(.horizontal)
                .padding(.bottom, 16)

            switch (metalProvider.isReady, appEnvironment.currentScreen) {
            case (false, _):
                ProgressView()
                    .frame(maxHeight: .infinity)
                    .controlSize(ControlSize.large)
            case (true, .home):
                HomeView()
            case (true, .objects):
                ZStack {
                    UniverseView(metalProvider: metalProvider)
                        .ignoresSafeArea(edges: .bottom)

                    if let summary = metalProvider.transferOrbitSummary {
                        TransferOrbitFormulaOverlay(summary: summary)
                            .padding(.top, 12)
                            .padding(.horizontal, 16)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                            .frame(maxWidth: .infinity,
                                   maxHeight: .infinity,
                                   alignment: .topTrailing)
                    }

                    if let selectedPlanet = appEnvironment.selectedPlanet {
                        Button {
                            metalProvider.showTransferOrbit(to: selectedPlanet)
                        } label: {
                            Text("Navigate to")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                        }
                        .background(.white, in: RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 24)
                        .padding(.bottom, 28)
                        .frame(maxWidth: .infinity,
                               maxHeight: .infinity,
                               alignment: .bottom)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: metalProvider.transferOrbitSummary)
        .task {
            await metalProvider.prepare()
        }
    }
}

#Preview {
    RootContainerView()
        .environment(AppEnvironment())
}
