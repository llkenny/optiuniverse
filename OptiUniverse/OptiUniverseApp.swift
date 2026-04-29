//
//  OptiUniverseApp.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI
import BaseModule

@main
struct OptiUniverseApp: App {
    @State private var appEnvironment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootContainerView()
                .environment(appEnvironment)
        }
    }
}
