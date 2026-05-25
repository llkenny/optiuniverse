//
//  OptiUniverseApp.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI
import BaseModule
import MetalModule

@main
struct OptiUniverseApp: App {
    @State private var appEnvironment = AppEnvironment()
    @State private var metalResources = MetalModuleFactory.makeResources()

    var body: some Scene {
        WindowGroup {
            RootContainerView(metalResources: metalResources)
                .environment(appEnvironment)
        }
    }
}
