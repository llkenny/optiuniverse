//
//  ContentView.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedPlanet: String?
    @State private var selectedPreset: String = "High"
    @State private var selectedDistance: String = "Near"
    private let planetNames = SolarSystemLoader.loadPlanets(from: "planets").map { $0.name }

    var body: some View {
        NavigationView {
            UniverseView(selectedPlanet: $selectedPlanet)
                .navigationTitle("Solar System")
                .toolbar {
                      ToolbarItemGroup(placement: .navigationBarTrailing) {
                          Menu("Objects") {
                              ForEach(planetNames, id: \.self) { name in
                                  Button(name) { selectedPlanet = name }
                              }
                          }
                          Menu("Preset") {
                              Button("Low") { selectedPreset = "Low" }
                                  .accessibilityIdentifier("Preset_Low")
                              Button("Medium") { selectedPreset = "Medium" }
                                  .accessibilityIdentifier("Preset_Medium")
                              Button("High") { selectedPreset = "High" }
                                  .accessibilityIdentifier("Preset_High")
                              Button("Cinematic") { selectedPreset = "Cinematic" }
                                  .accessibilityIdentifier("Preset_Cinematic")
                          }
                          Menu("Distance") {
                              Button("Near") { selectedDistance = "Near" }
                                  .accessibilityIdentifier("Distance_Near")
                              Button("Far") { selectedDistance = "Far" }
                                  .accessibilityIdentifier("Distance_Far")
                          }
                          Button("Settings") {
                              // Open settings
                          }
                          .accessibilityIdentifier("Settings")
                          if QALaunch.enabled {
                              Button("Export_QA") {
                                  QAHooks.export()
                              }
                              .accessibilityIdentifier("Export_QA")
                              Button("QA_SampleMemory") {
                                  QAHooks.sampleMemory()
                              }
                              .accessibilityIdentifier("QA_SampleMemory")
                              Button("QA_ExportStability") {
                                  QAHooks.exportStability()
                              }
                              .accessibilityIdentifier("QA_ExportStability")
                          }
                      }
                  }
          }
      }
  }

#Preview {
    ContentView()
}
