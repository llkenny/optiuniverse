import RealityKit
import simd
import Testing
@testable import UniverseModule

@MainActor
@Test func celestialTextureMeridiansAgreeWithSurfaceCoordinateFrame() async throws {
    let repository = RealityAssetRepository()
    let manifest = try CelestialAssetManifestLoader.load()
    for asset in manifest.assets {
        let root = try await repository.entity(for: asset)
        let body = try #require(root.findEntity(named: "Body"))
        let model = try #require(body.components[ModelComponent.self])
        let mesh = try #require(model.mesh.contents.models.first)
        let part = try #require(mesh.parts.first)
        let coordinates = try #require(part.textureCoordinates?.elements)
        let positions = part.positions.elements
        func direction(at textureCoordinate: SIMD2<Float>) throws -> SIMD3<Float> {
            let nearest = try #require(coordinates.indices.min {
                simd_length_squared(coordinates[$0] - textureCoordinate)
                    < simd_length_squared(coordinates[$1] - textureCoordinate)
            })
            let point = body.transformMatrix(relativeTo: root) * SIMD4<Float>(positions[nearest], 1)
            let correction = asset.orientationCorrection
            let rotation = simd_quatf(ix: correction.xAxis, iy: correction.yAxis,
                                       iz: correction.zAxis, r: correction.real)
            return rotation.act(simd_normalize(SIMD3(point.x, point.y, point.z)))
        }
        // USDZ Sphere's texture midpoint faces -X before its manifest correction.
        // Canonical zero/east/north must face +X/-Z/+Y for dated surface coordinates.
        #expect(simd_distance(try direction(at: SIMD2(0.5, 0.5)), SIMD3(1, 0, 0)) < 0.001)
        #expect(simd_distance(try direction(at: SIMD2(0.75, 0.5)), SIMD3(0, 0, -1)) < 0.001)
        #expect(simd_distance(try direction(at: SIMD2(0.5, 1)), SIMD3(0, 1, 0)) < 0.001)
    }
}
