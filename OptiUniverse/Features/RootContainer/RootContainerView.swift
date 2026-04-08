//
//  RootContainerView.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI

struct RootContainerView: View {
    
    @Environment(AppEnvironment.self) private var appEnvironment
    private let planetNames = SolarSystemLoader.loadPlanets(from: "planets").map { $0.name }
    
    var body: some View {
        VStack(spacing: 0) {
            TopBarView(
                viewModel: TopBarViewModel(planetNames: planetNames)
            )
            .padding(.horizontal)
            
            Spacer(minLength: 16)
            
            switch appEnvironment.currentScreen {
                case .home:
                    HomeView()
                case .objects:
                    UniverseView()
            }
        }
    }
}

#Preview {
    RootContainerView()
        .environment(AppEnvironment())
}
