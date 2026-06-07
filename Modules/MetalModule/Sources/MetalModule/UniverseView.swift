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
    let resources: MetalModuleResources

    public init(resources: MetalModuleResources) {
        self.resources = resources
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

        let renderer = resources.makeRenderer(for: mtkView)
        context.coordinator.renderer = renderer

        let cameraController = CameraController(cameraCoordinator: resources.cameraCoordinator,
                                                beginManualCameraControl: { [resources] in
                                                    resources.beginManualCameraControl()
                                                },
                                                isTrajectoryModeActive: { [resources] in
                                                    resources.isTrajectoryModeActive
                                                })
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
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        let selectedDestinationID = appEnvironment.selectedDestinationID
        let selectedPlanet = appEnvironment.selectedPlanet

        if context.coordinator.currentSelectedDestinationID != selectedDestinationID ||
            context.coordinator.currentSelectedPlanet != selectedPlanet {
            context.coordinator.currentSelectedDestinationID = selectedDestinationID
            context.coordinator.currentSelectedPlanet = selectedPlanet

            if let selectedDestinationID {
                resources.followDestination(
                    identifiedBy: selectedDestinationID,
                    destinations: appEnvironment.destinationsProvider.destinations
                )
            } else if let name = selectedPlanet {
                resources.followPlanet(named: name,
                                       surfaceLocation: nil)
            }
        }
    }

    public static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.renderer?.dismantle()
        coordinator.cameraController = nil
        coordinator.renderer = nil
    }
}
