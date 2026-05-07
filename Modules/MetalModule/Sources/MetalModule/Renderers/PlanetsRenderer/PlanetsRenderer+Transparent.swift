//
//  PlanetsRenderer+Transparent.swift
//  MetalModule
//
//  Created by max on 07.05.2026.
//

extension PlanetsRenderer {

    func isTransparentCompanionMesh(_ loadedMesh: LoadedMesh) -> Bool {
        isNamedTransparentMesh(loadedMesh) ||
        loadedMesh.textures.contains {
            $0.materialUniforms.usesBaseColorAlpha > 0.5 ||
            $0.materialUniforms.usesOpacityTexture > 0.5
        }
    }

    func hasTransparentSubmesh(in planet: PreparedPlanetRenderPacket) -> Bool {
        planet.meshes.contains { loadedMesh in
            loadedMesh.mesh.submeshes.indices.contains { submeshIndex in
                isTransparentSubmesh(loadedMesh,
                                     submeshIndex: submeshIndex,
                                     planet: planet)
            }
        }
    }

    func isTransparentSubmesh(_ loadedMesh: LoadedMesh,
                              submeshIndex: Int,
                              planet: PreparedPlanetRenderPacket) -> Bool {
        let textures = loadedMesh.textures[safe: submeshIndex]
        let uniforms = materialUniforms(for: planet,
                                        loadedMesh: loadedMesh,
                                        renderPass: .transparent,
                                        textures: textures)
        return isTransparentMaterial(uniforms) ||
        (textures == nil && isNamedTransparentMesh(loadedMesh))
    }

    private func isTransparentMaterial(_ materialUniforms: MaterialUniforms) -> Bool {
        materialUniforms.usesBaseColorAlpha > 0.5 ||
        materialUniforms.usesOpacityTexture > 0.5 ||
        materialUniforms.opacityFactor < 0.999 ||
        materialUniforms.rimAlphaStrength > 0.5
    }
}
