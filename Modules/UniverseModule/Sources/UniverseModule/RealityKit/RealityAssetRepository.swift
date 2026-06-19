import Foundation
import RealityKit

@MainActor
final class RealityAssetRepository {
    enum RepositoryError: Error, Equatable {
        case missingAsset(String)
        case missingCanonicalRoot(assetName: String, rootName: String)
    }

    typealias EntityLoader = @MainActor (URL) async throws -> Entity

    private struct AssetKey: Hashable {
        let assetName: String
        let canonicalRootName: String
    }

    private let bundle: Bundle
    private let entityLoader: EntityLoader
    private var prototypes: [AssetKey: Entity] = [:]
    private var loadingTasks: [AssetKey: Task<Entity, Error>] = [:]

    init(bundle: Bundle = .module,
         entityLoader: @escaping EntityLoader = { try await Entity(contentsOf: $0) }) {
        self.bundle = bundle
        self.entityLoader = entityLoader
    }

    func entity(assetName: String,
                canonicalRootName: String) async throws -> Entity {
        let key = AssetKey(assetName: assetName,
                           canonicalRootName: canonicalRootName)
        if let prototype = prototypes[key] {
            return prototype.clone(recursive: true)
        }

        if let loadingTask = loadingTasks[key] {
            return try await loadingTask.value.clone(recursive: true)
        }

        guard let assetURL = bundle.url(forResource: assetName,
                                        withExtension: "usdz") else {
            throw RepositoryError.missingAsset(assetName)
        }

        let entityLoader = entityLoader
        let task = Task { @MainActor in
            let loadedEntity = try await entityLoader(assetURL)
            if loadedEntity.name == canonicalRootName {
                return loadedEntity
            }
            guard let canonicalRoot = loadedEntity.findEntity(named: canonicalRootName) else {
                throw RepositoryError.missingCanonicalRoot(assetName: assetName,
                                                           rootName: canonicalRootName)
            }
            canonicalRoot.removeFromParent(preservingWorldTransform: false)
            return canonicalRoot
        }
        loadingTasks[key] = task

        do {
            let prototype = try await task.value
            loadingTasks[key] = nil
            prototypes[key] = prototype
            return prototype.clone(recursive: true)
        } catch {
            loadingTasks[key] = nil
            throw error
        }
    }

    func entity(for asset: CelestialAssetDescriptor) async throws -> Entity {
        try await entity(assetName: asset.assetName,
                         canonicalRootName: asset.canonicalRootName)
    }

    func cancelPendingLoads() {
        loadingTasks.values.forEach { $0.cancel() }
        loadingTasks.removeAll()
    }
}
