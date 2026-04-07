//
//  TopBarViewModel.swift
//  OptiUniverse
//
//  Created by max on 07.04.2026.
//

import Observation

@Observable
final class TopBarViewModel {
    let planetNames: [String]
    
    init(planetNames: [String]) {
        self.planetNames = planetNames
    }
}
