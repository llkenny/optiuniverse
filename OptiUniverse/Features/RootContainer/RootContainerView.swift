//
//  RootContainerView.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI

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
                    Spacer()
                    ProgressView()
                    Spacer()
                case (true, .home):
                    HomeView()
                case (true, .objects):
                    UniverseView(metalProvider: metalProvider)
                        .ignoresSafeArea(edges: .bottom)
            }
        }
        .task {
            await metalProvider.prepare()
        }
    }
}

#Preview {
    RootContainerView()
        .environment(AppEnvironment())
}
