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
