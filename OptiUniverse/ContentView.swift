//
//  ContentView.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            UniverseView()
                .navigationTitle("Solar System")
                .toolbar {
                    Button("Settings") {
                        // Open settings
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
