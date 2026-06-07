//
//  RendererCoordinator.swift
//  MetalModule
//
//  Created by max on 05.05.2026.
//

internal import BaseModule

@MainActor
public final class RendererCoordinator {
    var renderer: MetalRenderer?
    var currentSelectedPlanet: String?
    var currentSelectedFollowTarget: ObjectFollowTarget?
    var cameraController: CameraController?
}
