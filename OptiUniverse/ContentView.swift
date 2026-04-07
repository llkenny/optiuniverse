//
//  ContentView.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI

struct ContentView: View {
    private let planetNames = SolarSystemLoader.loadPlanets(from: "planets").map { $0.name }
    
    var body: some View {
        NavigationView {
            VStack {
                TopBarView(
                    viewModel: TopBarViewModel(planetNames: planetNames)
                )
                .padding(.horizontal)
                UniverseView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(UniverseSelectionState())
}
