//
//  OptiUniverseApp.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI

@main
struct OptiUniverseApp: App {
    @State private var universeSelectionState = UniverseSelectionState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(universeSelectionState)
        }
    }
}
