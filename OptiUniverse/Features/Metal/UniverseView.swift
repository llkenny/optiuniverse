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
    @Environment(AppEnvironment.self) private var appEnvironment

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

    func updateUIView(_ uiView: UIView, context: Context) {
        let selectedPlanet = appEnvironment.selectedPlanet

        if context.coordinator.currentSelectedPlanet != selectedPlanet {
            context.coordinator.currentSelectedPlanet = selectedPlanet
            if let name = selectedPlanet {
                context.coordinator.renderer?.followPlanet(named: name)
            }
        }
    }
}

class RendererCoordinator: NSObject, PlanetLabelDelegate {
    var renderer: MetalRenderer?
    private var labels: [String: UILabel] = [:]
    var currentSelectedPlanet: String?
    var cameraController: CameraController?

    override init() {}

    func setupLabels(in view: UIView, planetNames: [String]) {
        for name in planetNames {
            let label = UILabel()
            label.text = name
            label.textColor = .white
            label.font = .systemFont(ofSize: 12)
            label.sizeToFit()
            label.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self,
                                             action: #selector(handleLabelTap(_:)))
            label.addGestureRecognizer(tap)
            view.addSubview(label)
            labels[name] = label
        }
    }

    func updatePlanetLabels(_ positions: [String : SIMD2<Float>]) {
        DispatchQueue.main.async {
            for (name, label) in self.labels {
                if let position = positions[name] {
                    label.center = CGPoint(x: CGFloat(position.x),
                                            y: CGFloat(position.y))
                    label.isHidden = false
                } else {
                    label.isHidden = true
                }
            }
        }
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(ofTouch: 0, in: gesture.view)
        print("Touch point\(point)")
        // TODO: Add objects selection
    }

    @objc func handleLabelTap(_ gesture: UITapGestureRecognizer) {
        guard let label = gesture.view as? UILabel,
              let name = label.text else { return }
        renderer?.followPlanet(named: name)
    }
}
