//
//  UniverseView.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI
import MetalKit
internal import BaseModule

public struct UniverseView: UIViewRepresentable {
    @Environment(AppEnvironment.self) private var appEnvironment
    let metalProvider: MetalProvider

    public init(metalProvider: MetalProvider) {
        self.metalProvider = metalProvider
    }

    public func makeCoordinator() -> RendererCoordinator {
        RendererCoordinator()
    }

    public func makeUIView(context: Context) -> UIView {
        let container = UIView()

        // Setup Metal view
        let mtkView = MTKView()
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(mtkView)
        NSLayoutConstraint.activate([
            mtkView.topAnchor.constraint(equalTo: container.topAnchor),
            mtkView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            mtkView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mtkView.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        // Initialize renderer and delegate
        let renderer = MetalRenderer(metalView: mtkView, metalProvider: metalProvider)
        context.coordinator.renderer = renderer
        metalProvider.renderer = renderer
        renderer?.labelDelegate = context.coordinator

        // Camera controller
        let cameraController = CameraController(renderer: renderer)
        context.coordinator.cameraController = cameraController

        // Add gesture recognizers to the Metal view
        let panGesture = UIPanGestureRecognizer(
            target: cameraController,
            action: #selector(CameraController.handlePan(_:)))
        mtkView.addGestureRecognizer(panGesture)
        let pinchGesture = UIPinchGestureRecognizer(
            target: cameraController,
            action: #selector(CameraController.handlePinch(_:)))
        mtkView.addGestureRecognizer(pinchGesture)
        let rotationGesture = UIRotationGestureRecognizer(
            target: cameraController,
            action: #selector(CameraController.handleRotation(_:)))
        mtkView.addGestureRecognizer(rotationGesture)
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:)))
        mtkView.addGestureRecognizer(tapGesture)

        return container
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        let selectedPlanet = appEnvironment.selectedPlanet

        if context.coordinator.currentSelectedPlanet != selectedPlanet {
            context.coordinator.currentSelectedPlanet = selectedPlanet
            if let name = selectedPlanet {
                context.coordinator.renderer?.followPlanet(named: name)
            }
        }
    }

    public static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.cameraController?.stop()
        coordinator.renderer?.metalProvider.renderer = nil
    }
}
