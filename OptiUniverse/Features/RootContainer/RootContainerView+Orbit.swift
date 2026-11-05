//
//  RootContainerView+Orbit.swift
//  OptiUniverse
//
//  Created by max on 11.05.2026.
//

import SwiftUI
import UniverseModule
import BaseModule

extension RootContainerView {

    var isOrbitPreview: Bool {
        appEnvironment.currentScreen == .objects && objectsViewState == .orbit
    }

    func closeTransferPreview() {
        universeResources.transferOrbit.clearTransferOrbit()
        objectsViewState = .raw
    }

    func retryTransferPreview() {
        if let destination = universeResources.transferPreviewSnapshot.destinationName {
            universeResources.transferOrbit.showTransferOrbit(to: destination)
        }
    }
}
