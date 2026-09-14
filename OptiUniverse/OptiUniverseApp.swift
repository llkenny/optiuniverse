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
    #if os(iOS)
    @Environment(\.scenePhase) private var scenePhase
    @State private var reviewCoordinator = ReviewRequestCoordinator()
    #endif

    var body: some Scene {
        #if os(visionOS)
        WindowGroup {
            VisionUniverseControlView(universeResources: universeResources)
                .environment(appEnvironment)
        }
        .defaultSize(width: 900, height: 720)

        ImmersiveSpace(id: VisionSceneID.universeImmersiveSpace) {
            UniverseImmersiveView(resources: universeResources)
                .environment(appEnvironment)
        }
        #else
        WindowGroup {
            RootContainerView(universeResources: universeResources)
                .environment(appEnvironment)
                #if os(iOS)
                .environment(reviewCoordinator)
                #endif
        }
        #if os(iOS)
        .onChange(of: scenePhase, initial: true) { _, phase in
            reviewCoordinator.scenePhaseChanged(phase)
        }
        #endif
        #endif
    }
}
