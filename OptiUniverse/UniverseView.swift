//
//  UniverseView.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI
import MetalKit
import UIKit

struct UniverseView: UIViewRepresentable {
    func makeCoordinator() -> RendererCoordinator {
        RendererCoordinator()
    }

    func makeUIView(context: Context) -> UIView {
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
        let renderer = MetalRenderer(metalView: mtkView)
        context.coordinator.renderer = renderer
        renderer?.labelDelegate = context.coordinator

        // Create static labels for planets
        let planets = SolarSystemLoader.loadPlanets(from: "planets")
        context.coordinator.setupLabels(in: container, planetNames: planets.map { $0.name })

        // Add gesture recognizers to the Metal view
        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePan))
        mtkView.addGestureRecognizer(panGesture)
        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch))
        mtkView.addGestureRecognizer(pinchGesture)
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:)))
        mtkView.addGestureRecognizer(tapGesture)

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

class RendererCoordinator: NSObject, PlanetLabelDelegate {
    var renderer: MetalRenderer?
    private var labels: [String: UILabel] = [:]

    // Touch state
    private var lastPanLocation: CGPoint = .zero

    override init() {}

    func setupLabels(in view: UIView, planetNames: [String]) {
        for name in planetNames {
            let label = UILabel()
            label.text = name
            label.textColor = .white
            label.font = .systemFont(ofSize: 12)
            label.sizeToFit()
            view.addSubview(label)
            labels[name] = label
        }
    }

    func updatePlanetLabels(_ positions: [String : SIMD2<Float>]) {
        DispatchQueue.main.async {
            for (name, position) in positions {
                if let label = self.labels[name] {
                    label.center = CGPoint(x: CGFloat(position.x),
                                            y: CGFloat(position.y))
                }
            }
        }
    }

    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.translation(in: gesture.view)
        let sensitivity: Float = 0.01

        renderer?.cameraYaw -= Float(location.x - lastPanLocation.x) * sensitivity
        renderer?.cameraPitch -= Float(location.y - lastPanLocation.y) * sensitivity
        renderer?.cameraPitch = max(0.1, min(renderer?.cameraPitch ?? 0, .pi/2))

        lastPanLocation = location
        renderer?.updateCamera()
    }

    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        let zoomSensitivity: Float = 1 // TODO: Think about its value
        renderer?.cameraDistance /= Float(gesture.scale) * zoomSensitivity
        renderer?.cameraDistance = max(0, min(renderer?.cameraDistance ?? 3, 100))
        gesture.scale = 1.0
        renderer?.updateCamera()
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(ofTouch: 0, in: gesture.view)
        print("Touch point\(point)")
        // TODO: Add objects selection
    }
}
