import Foundation
import RealityKit

@MainActor
final class RealityAssetRepository {
    enum RepositoryError: Error, Equatable {
        case missingAsset(String)
        case missingCanonicalRoot(assetName: String, rootName: String)
    }

    typealias EntityLoader = @MainActor (URL) async throws -> Entity

    private let bundle: Bundle
    private let entityLoader: EntityLoader
    private var sourcePrototypes: [String: Entity] = [:]
    private var loadingTasks: [String: Task<Entity, Error>] = [:]

    init(bundle: Bundle = .module,
         entityLoader: @escaping EntityLoader = { try await Entity(contentsOf: $0) }) {
        self.bundle = bundle
        self.entityLoader = entityLoader
    }

    func entity(assetName: String,
                canonicalRootName: String) async throws -> Entity {
        try await entity(assetName: assetName, rootNames: [canonicalRootName])
    }

    func entity(assetName: String, rootNames: [String]) async throws -> Entity {
        let source = try await sourceEntity(assetName: assetName)
        return try extract(rootNames: rootNames,
                           assetName: assetName,
                           from: source)
    }

    private func sourceEntity(assetName: String) async throws -> Entity {
        if let prototype = sourcePrototypes[assetName] {
            return prototype
        }

        if let loadingTask = loadingTasks[assetName] {
            return try await loadingTask.value
        }

        guard let assetURL = bundle.url(forResource: assetName,
                                        withExtension: "usdz") else {
            throw RepositoryError.missingAsset(assetName)
        }

        let entityLoader = entityLoader
        let task = Task { @MainActor in
            try await entityLoader(assetURL)
        }
        loadingTasks[assetName] = task

        do {
            let prototype = try await task.value
            loadingTasks[assetName] = nil
            sourcePrototypes[assetName] = prototype
            return prototype
        } catch {
            loadingTasks[assetName] = nil
            throw error
        }
    }

    private func extract(rootNames: [String],
                         assetName: String,
                         from source: Entity) throws -> Entity {
        guard let canonicalRootName = rootNames.first else {
            throw RepositoryError.missingCanonicalRoot(assetName: assetName,
                                                       rootName: "")
        }

        if rootNames.count == 1, source.name == canonicalRootName {
            return source.clone(recursive: true)
        }

        let container = Entity()
        container.name = canonicalRootName
        for rootName in rootNames {
            guard let sourceRoot = source.findEntity(named: rootName) else {
                throw RepositoryError.missingCanonicalRoot(assetName: assetName,
                                                           rootName: rootName)
            }
            let clone = sourceRoot.clone(recursive: true)
            container.addChild(clone)
        }
        return container
    }

    func entity(for asset: CelestialAssetDescriptor) async throws -> Entity {
        try await entity(assetName: asset.assetName,
                         rootNames: asset.rootNames)
    }

    func cancelPendingLoads() {
        loadingTasks.values.forEach { $0.cancel() }
        loadingTasks.removeAll()
    }
}
