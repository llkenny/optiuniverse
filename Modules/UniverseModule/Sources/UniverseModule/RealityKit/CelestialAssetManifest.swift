import Foundation

struct CelestialAssetVector3: Decodable, Sendable, Equatable {
    enum CodingKeys: String, CodingKey {
        case xAxis = "x"
        case yAxis = "y"
        case zAxis = "z"
    }

    let xAxis: Float
    let yAxis: Float
    let zAxis: Float

    var values: [Float] { [xAxis, yAxis, zAxis] }
}

struct CelestialAssetQuaternion: Decodable, Sendable, Equatable {
    enum CodingKeys: String, CodingKey {
        case xAxis = "x"
        case yAxis = "y"
        case zAxis = "z"
        case real = "w"
    }

    let xAxis: Float
    let yAxis: Float
    let zAxis: Float
    let real: Float

    var values: [Float] { [xAxis, yAxis, zAxis, real] }
}

struct CelestialAssetManifest: Decodable, Sendable {
    enum ValidationError: Error, Equatable {
        case emptyManifest
        case emptyValue(identity: String, field: String)
        case duplicateIdentity(String)
        case invalidFilename(identity: String, filename: String)
        case invalidNumericValue(identity: String, field: String)
        case invalidOrientation(identity: String)
        case selfParent(String)
        case missingParent(identity: String, parentIdentity: String)
        case missingAsset(String)
    }

    let assets: [CelestialAssetDescriptor]

    func validated(assetExists: (String) -> Bool = { _ in true }) throws -> Self {
        guard !assets.isEmpty else {
            throw ValidationError.emptyManifest
        }

        var identities = Set<String>()
        for asset in assets {
            try asset.validate()
            guard identities.insert(asset.identity).inserted else {
                throw ValidationError.duplicateIdentity(asset.identity)
            }
            guard assetExists(asset.filename) else {
                throw ValidationError.missingAsset(asset.filename)
            }
        }

        for asset in assets {
            guard let parentIdentity = asset.parentIdentity else { continue }
            guard parentIdentity != asset.identity else {
                throw ValidationError.selfParent(asset.identity)
            }
            guard identities.contains(parentIdentity) else {
                throw ValidationError.missingParent(identity: asset.identity,
                                                    parentIdentity: parentIdentity)
            }
        }

        return self
    }
}

struct CelestialAssetDescriptor: Decodable, Sendable, Equatable {
    let identity: String
    let displayName: String
    let filename: String
    let canonicalRootName: String
    let additionalRootNames: [String]
    let parentIdentity: String?
    // Some legacy exports keep planet scale in the simulation snapshot instead of the USDZ root.
    let usesSnapshotScale: Bool
    let modelToUniverseScale: Float
    let referenceRadius: Float
    let pivotCorrection: CelestialAssetVector3
    let orientationCorrection: CelestialAssetQuaternion
    let renderRadius: Float
    let framingRadius: Float
    let surfaceRadius: Float

    var assetName: String {
        URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
    }

    var rootNames: [String] {
        [canonicalRootName] + additionalRootNames
    }

    enum CodingKeys: String, CodingKey {
        case identity
        case displayName
        case filename
        case canonicalRootName
        case additionalRootNames
        case parentIdentity
        case usesSnapshotScale
        case modelToUniverseScale
        case referenceRadius
        case pivotCorrection
        case orientationCorrection
        case renderRadius
        case framingRadius
        case surfaceRadius
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        identity = try container.decode(String.self, forKey: .identity)
        displayName = try container.decode(String.self, forKey: .displayName)
        filename = try container.decode(String.self, forKey: .filename)
        canonicalRootName = try container.decode(String.self, forKey: .canonicalRootName)
        additionalRootNames = try container.decodeIfPresent([String].self,
                                                             forKey: .additionalRootNames) ?? []
        parentIdentity = try container.decodeIfPresent(String.self, forKey: .parentIdentity)
        usesSnapshotScale = try container.decodeIfPresent(Bool.self,
                                                           forKey: .usesSnapshotScale) ?? false
        modelToUniverseScale = try container.decode(Float.self, forKey: .modelToUniverseScale)
        referenceRadius = try container.decode(Float.self, forKey: .referenceRadius)
        pivotCorrection = try container.decode(CelestialAssetVector3.self,
                                               forKey: .pivotCorrection)
        orientationCorrection = try container.decode(CelestialAssetQuaternion.self,
                                                      forKey: .orientationCorrection)
        renderRadius = try container.decode(Float.self, forKey: .renderRadius)
        framingRadius = try container.decode(Float.self, forKey: .framingRadius)
        surfaceRadius = try container.decode(Float.self, forKey: .surfaceRadius)
    }

    init(identity: String,
         displayName: String,
         filename: String,
         canonicalRootName: String,
         additionalRootNames: [String] = [],
         parentIdentity: String? = nil,
         usesSnapshotScale: Bool = false,
         modelToUniverseScale: Float,
         referenceRadius: Float,
         pivotCorrection: CelestialAssetVector3,
         orientationCorrection: CelestialAssetQuaternion,
         renderRadius: Float,
         framingRadius: Float,
         surfaceRadius: Float) {
        self.identity = identity
        self.displayName = displayName
        self.filename = filename
        self.canonicalRootName = canonicalRootName
        self.additionalRootNames = additionalRootNames
        self.parentIdentity = parentIdentity
        self.usesSnapshotScale = usesSnapshotScale
        self.modelToUniverseScale = modelToUniverseScale
        self.referenceRadius = referenceRadius
        self.pivotCorrection = pivotCorrection
        self.orientationCorrection = orientationCorrection
        self.renderRadius = renderRadius
        self.framingRadius = framingRadius
        self.surfaceRadius = surfaceRadius
    }

    fileprivate func validate() throws {
        let strings = [
            ("identity", identity),
            ("displayName", displayName),
            ("filename", filename),
            ("canonicalRootName", canonicalRootName)
        ]
        for (field, value) in strings where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CelestialAssetManifest.ValidationError.emptyValue(identity: identity, field: field)
        }
        for rootName in additionalRootNames
        where rootName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CelestialAssetManifest.ValidationError.emptyValue(identity: identity,
                                                                    field: "additionalRootNames")
        }
        guard Set(rootNames).count == rootNames.count else {
            throw CelestialAssetManifest.ValidationError.emptyValue(identity: identity,
                                                                    field: "additionalRootNames")
        }

        guard URL(fileURLWithPath: filename).pathExtension.lowercased() == "usdz" else {
            throw CelestialAssetManifest.ValidationError.invalidFilename(identity: identity,
                                                                          filename: filename)
        }

        let positiveValues = [
            ("modelToUniverseScale", modelToUniverseScale),
            ("referenceRadius", referenceRadius),
            ("renderRadius", renderRadius),
            ("framingRadius", framingRadius),
            ("surfaceRadius", surfaceRadius)
        ]
        for (field, value) in positiveValues where !value.isFinite || value <= 0 {
            throw CelestialAssetManifest.ValidationError.invalidNumericValue(identity: identity,
                                                                             field: field)
        }
        guard pivotCorrection.values.allSatisfy(\.isFinite) else {
            throw CelestialAssetManifest.ValidationError.invalidNumericValue(identity: identity,
                                                                             field: "pivotCorrection")
        }

        let orientationValues = orientationCorrection.values
        let orientationLengthSquared = orientationValues.reduce(0) { $0 + ($1 * $1) }
        guard orientationValues.allSatisfy(\.isFinite),
              orientationLengthSquared.isFinite,
              abs(orientationLengthSquared - 1) < 0.001 else {
            throw CelestialAssetManifest.ValidationError.invalidOrientation(identity: identity)
        }
    }
}

enum CelestialAssetManifestLoader {
    static func load(bundle: Bundle = .module,
                     resourceName: String = "celestial_assets") throws -> CelestialAssetManifest {
        guard let manifestURL = bundle.url(forResource: resourceName, withExtension: "json") else {
            throw CelestialAssetManifest.ValidationError.missingAsset("\(resourceName).json")
        }

        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(CelestialAssetManifest.self, from: data)
        return try manifest.validated { filename in
            let fileURL = URL(fileURLWithPath: filename)
            return bundle.url(forResource: fileURL.deletingPathExtension().lastPathComponent,
                              withExtension: fileURL.pathExtension) != nil
        }
    }
}
