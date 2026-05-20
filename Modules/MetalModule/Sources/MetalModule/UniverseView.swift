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
    let meshProvider: MeshProvider
    let orbitRenderHandler: OrbitRenderHandler
    let navigationRenderHandler: NavigationRenderHandler

    public init(meshProvider: MeshProvider,
                orbitRenderHandler: OrbitRenderHandler,
                navigationRenderHandler: NavigationRenderHandler) {
        self.meshProvider = meshProvider
        self.orbitRenderHandler = orbitRenderHandler
        self.navigationRenderHandler = navigationRenderHandler
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

        let cameraState = CameraState()
        // CameraController can live more than renderer,so it owns cameraState
        let renderer = MetalRenderer(metalView: mtkView,
                                     cameraState: cameraState,
                                     meshProvider: meshProvider,
                                     navigationRenderHandler: navigationRenderHandler)
        context.coordinator.renderer = renderer
        orbitRenderHandler.renderer = renderer
        navigationRenderHandler.renderer = renderer
        renderer?.labelDelegate = context.coordinator

        let cameraController = CameraController(cameraState: cameraState,
                                                renderer: renderer)
        context.coordinator.cameraController = cameraController
        setupGestures(mtkView: mtkView,
                      cameraController: cameraController,
                      coordinator: context.coordinator)

        return container
    }

    private func setupGestures(mtkView: MTKView,
                               cameraController: CameraController,
                               coordinator: Coordinator) {
        let panGesture = UIPanGestureRecognizer(
            target: cameraController,
            action: #selector(CameraController.handlePan(_:)))
        panGesture.maximumNumberOfTouches = 1
        mtkView.addGestureRecognizer(panGesture)
        let trajectoryPanGesture = UIPanGestureRecognizer(
            target: cameraController,
            action: #selector(CameraController.handleTrajectoryPan(_:)))
        trajectoryPanGesture.minimumNumberOfTouches = 2
        trajectoryPanGesture.maximumNumberOfTouches = 2
        trajectoryPanGesture.delegate = cameraController
        mtkView.addGestureRecognizer(trajectoryPanGesture)
        let pinchGesture = UIPinchGestureRecognizer(
            target: cameraController,
            action: #selector(CameraController.handlePinch(_:)))
        mtkView.addGestureRecognizer(pinchGesture)
        let rotationGesture = UIRotationGestureRecognizer(
            target: cameraController,
            action: #selector(CameraController.handleRotation(_:)))
        mtkView.addGestureRecognizer(rotationGesture)
        let tapGesture = UITapGestureRecognizer(
            target: coordinator,
            action: #selector(Coordinator.handleTap(_:)))
        mtkView.addGestureRecognizer(tapGesture)
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
        coordinator.renderer = nil
    }
}
