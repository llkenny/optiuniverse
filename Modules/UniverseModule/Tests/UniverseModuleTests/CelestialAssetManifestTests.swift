import Foundation
import RealityKit
import Testing
@testable import UniverseModule

@Test func celestialAssetManifestContainsMigratedBodies() throws {
    let manifest = try CelestialAssetManifestLoader.load()
    let identities = Set(manifest.assets.map(\.identity))

    #expect(identities == ["sun", "mercury", "venus", "earth", "moon", "mars",
                           "jupiter", "saturn", "uranus", "neptune", "pluto"])
    #expect(manifest.assets.allSatisfy { $0.filename.hasSuffix(".usdz") })
    #expect(manifest.assets.allSatisfy { $0.modelToUniverseScale.isFinite })
    #expect(manifest.assets.allSatisfy { $0.referenceRadius.isFinite })
}

@Test func celestialAssetManifestRejectsDuplicateIdentities() {
    let asset = makeAssetDescriptor(identity: "sun")
    let manifest = CelestialAssetManifest(assets: [asset, asset])

    #expect(throws: CelestialAssetManifest.ValidationError.duplicateIdentity("sun")) {
        try manifest.validated()
    }
}

@Test func celestialAssetManifestRejectsInvalidMetadata() {
    let invalidScale = makeAssetDescriptor(identity: "sun",
                                           modelToUniverseScale: .infinity)
    let missingParent = makeAssetDescriptor(identity: "neptune",
                                            parentIdentity: "sun")

    #expect(
        throws: CelestialAssetManifest.ValidationError.invalidNumericValue(
            identity: "sun",
            field: "modelToUniverseScale"
        )
    ) {
        try CelestialAssetManifest(assets: [invalidScale]).validated()
    }
    #expect(
        throws: CelestialAssetManifest.ValidationError.missingParent(
            identity: "neptune",
            parentIdentity: "sun"
        )
    ) {
        try CelestialAssetManifest(assets: [missingParent]).validated()
    }
}

@MainActor
@Test func celestialAssetManifestAssetsLoadWithValidRootsBoundsAndMaterials() async throws {
    let manifest = try CelestialAssetManifestLoader.load()
    let repository = RealityAssetRepository()

    for asset in manifest.assets {
        let root = try await repository.entity(for: asset)
        let bounds = root.visualBounds(relativeTo: root)
        let extents = bounds.extents
        let modelRootName = asset.usesSnapshotScale ? asset.canonicalRootName : "Body"
        // TODO: Fix assets naming (should be named "Body")
        let body = try #require(root.findEntity(named: modelRootName))
        let model = try #require(firstModelComponent(in: body))

        #expect(root.name == asset.canonicalRootName)
        #expect(extents.x.isFinite && extents.y.isFinite && extents.z.isFinite)
        #expect(extents.x > 0 && extents.y > 0 && extents.z > 0)
        if !asset.usesSnapshotScale {
            let expectedModelDiameter = (asset.referenceRadius / asset.modelToUniverseScale) * 2
            #expect(abs(extents.x - expectedModelDiameter) < 0.005)
            #expect(abs(extents.y - expectedModelDiameter) < 0.005)
            #expect(abs(extents.z - expectedModelDiameter) < 0.005)
        }
        #expect(!model.materials.isEmpty)

        for additionalRootName in asset.additionalRootNames {
            let additionalRoot = try #require(root.findEntity(named: additionalRootName))
            let additionalModel = try #require(firstModelComponent(in: additionalRoot))
            #expect(!additionalModel.materials.isEmpty)
        }

        if asset.identity == "sun" {
            let corona = try #require(root.findEntity(named: "Corona"))
            let coronaModel = try #require(corona.components[ModelComponent.self])
            #expect(!coronaModel.materials.isEmpty)
        }
    }
}

@MainActor
private func firstModelComponent(in entity: Entity) -> ModelComponent? {
    if let model = entity.components[ModelComponent.self] {
        return model
    }
    for child in entity.children {
        if let model = firstModelComponent(in: child) {
            return model
        }
    }
    return nil
}

private func makeAssetDescriptor(
    identity: String,
    parentIdentity: String? = nil,
    modelToUniverseScale: Float = 1
) -> CelestialAssetDescriptor {
    CelestialAssetDescriptor(
        identity: identity,
        displayName: identity.capitalized,
        filename: "\(identity.capitalized).usdz",
        canonicalRootName: "Root",
        additionalRootNames: [],
        parentIdentity: parentIdentity,
        usesSnapshotScale: false,
        modelToUniverseScale: modelToUniverseScale,
        referenceRadius: 1,
        pivotCorrection: .init(xAxis: 0, yAxis: 0, zAxis: 0),
        orientationCorrection: .init(xAxis: 0, yAxis: 0, zAxis: 0, real: 1),
        renderRadius: 1,
        framingRadius: 1,
        surfaceRadius: 1
    )
}
