//
//  OptiUniverseApp.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI
import BaseModule
import UniverseModule

@main
struct OptiUniverseApp: App {
    @State private var appEnvironment = AppEnvironment()
    @State private var universeResources = UniverseModuleFactory.makeResources()

    var body: some Scene {
        WindowGroup {
            RootContainerView(universeResources: universeResources)
                .environment(appEnvironment)
        }
    }
}
