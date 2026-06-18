//
//  PlanetsRenderer+Specific.swift
//  UniverseModule
//
//  Created by max on 07.05.2026.
//
//  Contains specific methods for high_resolution_solar_system.usdz

extension PlanetsRenderer {

    func materialUniforms(for planet: PreparedPlanetRenderPacket,
                          loadedMesh: LoadedMesh,
                          renderPass: RenderPass,
                          textures: Textures?) -> MaterialUniforms {
        var materialUniforms = textures?.materialUniforms ?? MaterialUniforms()
        let meshName = loadedMesh.mesh.name
        if planet.planetName == "Sun" {
            materialUniforms.unlit = 1
        }
        if meshName.localizedCaseInsensitiveContains("SunCorona") {
            materialUniforms.rimAlphaStrength = 2.5
        }
        if meshName.localizedCaseInsensitiveContains("Atmosphere") {
            materialUniforms.opacityFactor *= 0.58
        }
        if meshName.localizedCaseInsensitiveContains("Nuvem") ||
            meshName.localizedCaseInsensitiveContains("Cloud") {
            materialUniforms.whiteAlbedo = 1
            materialUniforms.opacityFactor *= 0.58
            materialUniforms.ambientOcclusionFactor = 1
        }
        let alphaGeometryRadius = alphaGeometryRadius(for: planet,
                                                      loadedMesh: loadedMesh)
        if alphaGeometryRadius > 0 {
            materialUniforms.usesOpacityTexture = 0
            switch renderPass {
            case .opaque:
                materialUniforms.usesBaseColorAlpha = 0
                materialUniforms.alphaGeometryRadius = -alphaGeometryRadius
            case .transparent:
                materialUniforms.usesBaseColorAlpha = 1
                materialUniforms.alphaGeometryRadius = alphaGeometryRadius
            }
        }
        return materialUniforms
    }

    func alphaGeometryRadius(for planet: PreparedPlanetRenderPacket,
                             loadedMesh: LoadedMesh) -> Float {
        guard planet.planetName == "Saturn" || planet.planetName == "Uranus",
              loadedMesh.mesh.name == planet.meshes.first?.mesh.name,
              loadedMesh.mesh.submeshes.count == 1,
              loadedMesh.boundsRadius > 0 else {
            return 0
        }

        // The current Saturn/Uranus USD meshes combine the sphere and rings in
        // one submesh. Split near the gap between sphere vertices and ring
        // vertices so each pass can use the right alpha/depth behavior.
        switch planet.planetName {
        case "Saturn":
            return loadedMesh.boundsRadius * 0.32
        case "Uranus":
            return loadedMesh.boundsRadius * 0.47
        default:
            return 0
        }
    }

    func isNamedTransparentMesh(_ loadedMesh: LoadedMesh) -> Bool {
        let meshName = loadedMesh.mesh.name
        return meshName.localizedCaseInsensitiveContains("Atmosphere") ||
        meshName.localizedCaseInsensitiveContains("Cloud") ||
        meshName.localizedCaseInsensitiveContains("Nuvem") ||
        meshName.localizedCaseInsensitiveContains("Corona")
    }
}
