//
//  RendererCoordinator.swift
//  MetalModule
//
//  Created by max on 05.05.2026.
//

@MainActor
public final class RendererCoordinator {
    var renderer: MetalRenderer?
    var currentSelectedPlanet: String?
    var cameraController: CameraController?
}
