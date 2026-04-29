//
//  ModelLoader.swift
//  OptiUniverse
//
//  Created by max on 27.03.2026.
//

@preconcurrency import ModelIO
import MetalKit

struct LoadedMesh: @unchecked Sendable {
    let mesh: MTKMesh
    let textures: [Textures]
    let boundsCenter: SIMD3<Float>
    let boundsRadius: Float
}

public actor ModelLoader {

    private let resourceName: String
    private let vertexDescriptor: MDLVertexDescriptor

    var meshes: [String: LoadedMesh] = [:]
    // TODO: Add missing:
    // ["JupiterLow_JupiterAtmosphere_0", "MoonLow_Moon_0", "PlutoLow_Pluto_0"]

    // TODO: Make ModelLoaderProtocol
    public init(resourceName: String) {
        self.resourceName = resourceName
        self.vertexDescriptor = MDLVertexDescriptor.makeUSDZVertexDescriptor()
    }

    func loadMeshes(device: MTLDevice) async {
        let url = Bundle.main.url(forResource: resourceName, withExtension: "usdz")!

        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(url: url,
                             vertexDescriptor: vertexDescriptor,
                             bufferAllocator: allocator)
        asset.loadTextures()

        let mdlMeshes = asset
            .childObjects(of: MDLMesh.self)
            .compactMap { $0 as? MDLMesh }

        meshes = await makeLoadedMeshes(mdlMeshes: mdlMeshes, device: device)
    }

    /// Creates a dictionary of meshes with loaded textures.
    /// MainActor because of texture is using CoreGraphics implicitly.
    /// - Parameters:
    ///   - mdlMeshes: Raw meshes
    ///   - device: Device for load a texture
    /// - Returns: Prepared meshes with textures
    @MainActor
    private func makeLoadedMeshes(mdlMeshes: [MDLMesh], device: MTLDevice) -> [String: LoadedMesh] {
        let loadedMeshes = mdlMeshes
            .compactMap { mdlMesh in
                let textures = (mdlMesh.submeshes as? [MDLSubmesh])?
                    .map {
                        Textures(material: $0.material, device: device)
                    } ?? []
                do {
                    let mesh = try MTKMesh(mesh: mdlMesh, device: device)
                    return LoadedMesh(mesh: mesh,
                                      textures: textures,
                                      boundsCenter: boundingCenter(of: mdlMesh),
                                      boundsRadius: boundingRadius(of: mdlMesh))
                } catch {
                    assertionFailure("MTKMesh init failed")
                    return nil
                }

            }
        return Dictionary(uniqueKeysWithValues: loadedMeshes.map { ($0.mesh.name, $0) })
    }

    func getMesh(name: String) -> LoadedMesh? {
        meshes[name]
    }

    func getMeshes(for planetName: String, primaryMeshName: String) -> [LoadedMesh] {
        let primary = meshes[primaryMeshName].map { [$0] } ?? []
        let extras = meshes
            .filter { meshName, _ in
                meshName != primaryMeshName &&
                meshName.localizedCaseInsensitiveContains(planetName)
            }
            .sorted { $0.key < $1.key }
            .map(\.value)

        return primary + extras
    }
}

private func boundingCenter(of mesh: MDLMesh) -> SIMD3<Float> {
    let bounds = mesh.boundingBox
    let min = bounds.minBounds
    let max = bounds.maxBounds
    return SIMD3<Float>((min.x + max.x) * 0.5,
                        (min.y + max.y) * 0.5,
                        (min.z + max.z) * 0.5)
}

private func boundingRadius(of mesh: MDLMesh) -> Float {
    let bounds = mesh.boundingBox
    let min = bounds.minBounds
    let max = bounds.maxBounds
    let center = boundingCenter(of: mesh)

    let corners: [SIMD3<Float>] = [
        [min.x, min.y, min.z],
        [min.x, min.y, max.z],
        [min.x, max.y, min.z],
        [min.x, max.y, max.z],
        [max.x, min.y, min.z],
        [max.x, min.y, max.z],
        [max.x, max.y, min.z],
        [max.x, max.y, max.z]
    ]

    return corners.map { simd_length($0 - center) }.max() ?? 1
}

private func rewriteTextureCoordinatesForRuntimePlanet(on mesh: MDLMesh) {
    guard
        let positionAttribute = mesh
            .vertexAttributeData(forAttributeNamed: MDLVertexAttributePosition,
                                 as: .float3),
        let texCoordAttribute = mesh
            .vertexAttributeData(forAttributeNamed: MDLVertexAttributeTextureCoordinate,
                                 as: .float2)
    else {
        return
    }

    let positions = positionAttribute.dataStart.bindMemory(to: SIMD3<Float>.self, capacity: mesh.vertexCount)
    let texCoords = texCoordAttribute.dataStart.bindMemory(to: SIMD2<Float>.self, capacity: mesh.vertexCount)

    for index in 0..<mesh.vertexCount {
        let direction = simd_normalize(positions[index])
        let uValue = atan2(direction.x, direction.z) / (2 * Float.pi) + 0.5
        let vValue = acos(max(-1, min(1, direction.y))) / Float.pi
        texCoords[index] = SIMD2<Float>(uValue, vValue)
    }
}
