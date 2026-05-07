//
//  PlanetsRendererProtocol.swift
//  MetalModule
//
//  Created by max on 07.05.2026.
//

protocol PlanetsRendererProtocol {

    /// Screen-space positions of planet centers, updated each frame.
    /// Keys are planet names, values are pixel coordinates in the viewport.
    var planetScreenPositions: [String: SIMD2<Float>] { get }

    /// Current simulation time used for planet animations.
    var currentTime: Float { get }

    // Advances the internal time accumulator and returns the time delta.
    /// Should be called once per frame before rendering so other systems can
    /// use the updated time (e.g. camera following).
    func advanceTime() -> Float

    func renderPlanets(configuration: PlanetRenderConfiguration)
}
