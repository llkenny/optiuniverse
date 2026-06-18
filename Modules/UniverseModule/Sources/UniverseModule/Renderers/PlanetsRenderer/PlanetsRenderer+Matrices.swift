//
//  PlanetsRenderer+Matrices.swift
//  UniverseModule
//
//  Created by max on 07.05.2026.
//

import simd

extension PlanetsRenderer {

    func localModelMatrix(for planet: PreparedPlanetRenderPacket,
                          loadedMesh: LoadedMesh,
                          sceneOrigin: SIMD3<Float>) -> float4x4 {
        var meshScale = planet.normalizedScale
        if loadedMesh.boundsRadius > 0,
           loadedMesh.boundsRadius < planet.primaryMeshRadius * 0.8,
           isTransparentCompanionMesh(loadedMesh) {
            meshScale = (planet.primaryMeshRadius * planet.normalizedScale * 1.02) / loadedMesh.boundsRadius
        }

        var matrix = planet.baseModelMatrix
        * float4x4.makeScale(SIMD3<Float>(repeating: meshScale))
        var translation = matrix.columns.3
        translation.x = planet.worldPosition.x - sceneOrigin.x
        translation.y = planet.worldPosition.y - sceneOrigin.y
        translation.z = planet.worldPosition.z - sceneOrigin.z
        matrix.columns.3 = translation
        return matrix
    }

    func meshCenter(for planet: PreparedPlanetRenderPacket,
                    loadedMesh: LoadedMesh,
                    sceneOrigin: SIMD3<Float>) -> SIMD3<Float> {
        let modelMatrix = localModelMatrix(for: planet,
                                           loadedMesh: loadedMesh,
                                           sceneOrigin: sceneOrigin)
        let center = modelMatrix * SIMD4<Float>(loadedMesh.boundsCenter, 1)
        return SIMD3<Float>(center.x, center.y, center.z)
    }

    func effectiveRenderRadius(for planet: PreparedPlanetRenderPacket,
                               loadedMesh: LoadedMesh) -> Float {
        if loadedMesh.boundsRadius > 0,
           loadedMesh.boundsRadius < planet.primaryMeshRadius * 0.8,
           isTransparentCompanionMesh(loadedMesh) {
            return planet.primaryMeshRadius * planet.normalizedScale * 1.02
        }

        return loadedMesh.boundsRadius * planet.normalizedScale
    }
}
