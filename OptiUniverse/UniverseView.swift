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
            action: #selector(Coordinator.handlePan(_:)))
        mtkView.addGestureRecognizer(panGesture)
        
        let pinchGesture = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:)))
        mtkView.addGestureRecognizer(pinchGesture)
        
        let rotationGesture = UIRotationGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleRotation(_:)))
        mtkView.addGestureRecognizer(rotationGesture)
        
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
    
    init() {}
    
    @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        renderer?.handlePanGesture(translation: translation)
        gesture.setTranslation(.zero, in: gesture.view)
    }
    
    @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
            case .began:
                renderer?.handlePinchGestureStart(scale: gesture.scale)
            case .changed:
                renderer?.handlePinchGestureChange(scale: gesture.scale)
            default:
                break
        }
    }
    
    @objc func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        let rotation = gesture.rotation
        print("Rotation \(rotation)")
        renderer?.handleRotationGesture(rotation: rotation)
    }
    
    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(ofTouch: 0, in: gesture.view)
        print("Touch point\(point)")
        // TODO: Add objects selection
    }
}
