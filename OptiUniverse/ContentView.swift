//
//  ContentView.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedPlanet: String?
    private let planetNames = SolarSystemLoader.loadPlanets(from: "planets").map { $0.name }

    var body: some View {
        NavigationView {
            UniverseView(selectedPlanet: $selectedPlanet)
                .toolbar {
                      ToolbarItemGroup(placement: .navigationBarTrailing) {
                          Menu("Objects") {
                              ForEach(planetNames, id: \.self) { name in
                                  Button(name) { selectedPlanet = name }
                              }
                          }
                      }
                  }
          }
      }
  }

#Preview {
    ContentView()
}
