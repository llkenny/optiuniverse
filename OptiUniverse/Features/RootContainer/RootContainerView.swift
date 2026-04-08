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
        NavigationView {
            VStack {
                TopBarView(
                    viewModel: TopBarViewModel(planetNames: planetNames)
                )
                .padding(.horizontal)
                switch appEnvironment.currentScreen {
                    case .home:
                        HomeView()
                    case .objects:
                        UniverseView()
                }
            }
        }
    }
}

#Preview {
    RootContainerView()
        .environment(AppEnvironment())
}
