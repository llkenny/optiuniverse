//
//  UniverseSelectionState.swift
//  OptiUniverse
//
//  Created by Codex on 08.04.2026.
//

import Observation

@Observable
final class UniverseSelectionState {
    
    var selectedPlanet: String?
    var location: String {
        "\(selectedPlanet ?? "Unknown"), Solar System, Milky Way"
    }
}
