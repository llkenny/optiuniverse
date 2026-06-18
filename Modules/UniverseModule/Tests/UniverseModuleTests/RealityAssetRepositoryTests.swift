import RealityKit
import Testing
@testable import UniverseModule

@MainActor
@Test func realityAssetRepositoryReportsMissingAsset() async {
    let repository = RealityAssetRepository()

    await #expect(throws: RealityAssetRepository.RepositoryError.missingAsset("NotAnAsset")) {
        try await repository.entity(assetName: "NotAnAsset",
                                    canonicalRootName: "Root")
    }
}

@MainActor
@Test func realityAssetRepositoryCachesPrototypeAndReturnsClones() async throws {
    var loadCount = 0
    let repository = RealityAssetRepository { _ in
        loadCount += 1
        let container = Entity()
        container.name = "Container"
        let canonicalRoot = Entity()
        canonicalRoot.name = "Earth"
        container.addChild(canonicalRoot)
        return container
    }

    let first = try await repository.entity(assetName: "high_resolution_solar_system",
                                            canonicalRootName: "Earth")
    let second = try await repository.entity(assetName: "high_resolution_solar_system",
                                             canonicalRootName: "Earth")

    #expect(loadCount == 1)
    #expect(first.name == "Earth")
    #expect(second.name == "Earth")
    #expect(first != second)
}

@MainActor
@Test func realityAssetRepositoryRejectsMissingCanonicalRoot() async {
    let repository = RealityAssetRepository { _ in
        let entity = Entity()
        entity.name = "Container"
        return entity
    }

    await #expect(
        throws: RealityAssetRepository.RepositoryError.missingCanonicalRoot(
            assetName: "high_resolution_solar_system",
            rootName: "Earth"
        )
    ) {
        try await repository.entity(assetName: "high_resolution_solar_system",
                                    canonicalRootName: "Earth")
    }
}
