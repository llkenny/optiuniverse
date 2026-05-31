//
//  PlanetsRenderer+PlanetsRendererProtocol.swift
//  MetalModule
//
//  Created by max on 07.05.2026.
//

import simd
import QuartzCore

extension PlanetsRenderer: PlanetsRendererProtocol {

    var currentTime: Float { time }

    func advanceTime() -> Float {
        let currentTime = CACurrentMediaTime()
        let delta = Float(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        time += delta
        return delta
    }

    func renderPlanets(configuration: PlanetRenderConfiguration) {
        planetScreenPositions.removeAll()

        guard let snapshot = configuration.snapshot else { return }

        configuration.renderEncoder.setRenderPipelineState(pipelineState)
        configuration.renderEncoder.setDepthStencilState(opaqueDepthStencilState)
        for planet in snapshot.planets {
            renderPlanet(planet,
                         renderPass: .opaque,
                         configuration: configuration)
        }

        let cameraWorldPosition = configuration.sceneOrigin + configuration.cameraOffset
        let transparentPlanets = snapshot.planets
            .filter { planet in
                hasTransparentSubmesh(in: planet)
            }
            .sorted {
                simd_distance_squared($0.worldPosition, cameraWorldPosition) >
                simd_distance_squared($1.worldPosition, cameraWorldPosition)
            }

        configuration.renderEncoder.setDepthStencilState(transparentDepthStencilState)
        for planet in transparentPlanets {
            renderPlanet(planet,
                         renderPass: .transparent,
                         configuration: configuration)
        }
    }
}
