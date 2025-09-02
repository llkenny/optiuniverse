//
//  UniverseView.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

import SwiftUI
import MetalKit

struct UniverseView: UIViewRepresentable {
    func makeCoordinator() -> RendererCoordinator {
        RendererCoordinator()
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.delegate = context.coordinator.renderer
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        
        // Initialize the renderer with the MTKView
        context.coordinator.renderer = MetalRenderer(metalView: mtkView)
        
        // Add gesture recognizers
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
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {}
}

class RendererCoordinator {
    var renderer: MetalRenderer?
    
    // Touch state
    private var lastPanLocation: CGPoint = .zero
    
    init() {}
    
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
        renderer?.cameraDistance = max(0, min(renderer?.cameraDistance ?? 3, 10000))
        gesture.scale = 1.0
        renderer?.updateCamera()
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(ofTouch: 0, in: gesture.view)
        print("Touch point\(point)")
        // TODO: Add objects selection
    }
}
