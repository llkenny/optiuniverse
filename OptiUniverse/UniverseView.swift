//
//  UniverseView.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//


// UniverseView.swift
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
        
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {}
}

class RendererCoordinator {
    var renderer: MetalRenderer?
    
    init() {}
}
