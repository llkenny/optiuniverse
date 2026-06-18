//
//  RendererCoordinator.swift
//  UniverseModule
//
//  Created by max on 05.05.2026.
//

import Foundation

@MainActor
public final class RendererCoordinator {
    var renderer: MetalRenderer?
    var currentSelectedDestinationID: UUID?
    var currentSelectedPlanet: String?
    var cameraController: CameraController?
}
