import MetalKit
import simd

struct MaterialUniforms: Sendable {
    var baseColorFactor: SIMD3<Float> = SIMD3<Float>(repeating: 1)
    var opacityFactor: Float = 1
    var roughnessFactor: Float = 1
    var metallicFactor: Float = 0
    var ambientOcclusionFactor: Float = 1
    var usesBaseColorAlpha: Float = 0
    var usesOpacityTexture: Float = 0
    var rimAlphaStrength: Float = 0
    var unlit: Float = 0
    var whiteAlbedo: Float = 0
    var padding: Float = 0
}

struct Textures: @unchecked Sendable {
    var baseColor: MTLTexture?
    var normal: MTLTexture?
    var roughness: MTLTexture?
    var metallic: MTLTexture?
    var ambientOcclusion: MTLTexture?
    var emissive: MTLTexture?
    var opacity: MTLTexture?
    var materialUniforms = MaterialUniforms()
}

extension Textures {
    init(material: MDLMaterial?, device: MTLDevice) {
        let textureLoader = MTKTextureLoader(device: device)

        func textureOptions(for semantic: MDLMaterialSemantic,
                            generateMipmaps: Bool) -> [MTKTextureLoader.Option: NSNumber] {
            let usesSRGB = semantic == .baseColor || semantic == .emission
            return [
                MTKTextureLoader.Option.generateMipmaps: NSNumber(booleanLiteral: generateMipmaps),
                MTKTextureLoader.Option.SRGB: NSNumber(booleanLiteral: usesSRGB)
            ]
        }

        func texture(from mdlTexture: MDLTexture?,
                     semantic: MDLMaterialSemantic) -> MTLTexture? {
            guard let mdlTexture else {
                return nil
            }

            let maxDimension = max(Int(mdlTexture.dimensions.x), Int(mdlTexture.dimensions.y))
            let shouldGenerateMipmaps = maxDimension > 1

            return try? textureLoader.newTexture(texture: mdlTexture,
                                                 options: textureOptions(for: semantic,
                                                                         generateMipmaps: shouldGenerateMipmaps))
        }

        func properties(with semantic: MDLMaterialSemantic) -> [MDLMaterialProperty] {
            material?.properties(with: semantic) ?? []
        }

        func textureProperty(with semantic: MDLMaterialSemantic) -> MDLMaterialProperty? {
            properties(with: semantic).first { $0.textureSamplerValue?.texture != nil }
        }

        func scalarFactor(for semantic: MDLMaterialSemantic,
                          default defaultValue: Float) -> Float {
            let semanticProperties = properties(with: semantic)
            if let scalarProperty = semanticProperties.first(where: { $0.textureSamplerValue?.texture == nil }) {
                return scalarProperty.floatValue
            }

            if textureProperty(with: semantic) != nil {
                return 1
            }

            return defaultValue
        }

        func colorFactor(for semantic: MDLMaterialSemantic,
                         default defaultValue: SIMD3<Float>) -> SIMD3<Float> {
            guard let property = properties(with: semantic)
                .first(where: { $0.textureSamplerValue?.texture == nil }) else {
                return defaultValue
            }

            let value4 = property.float4Value
            let candidate = SIMD3<Float>(value4.x, value4.y, value4.z)
            if !candidate.x.isZero || !candidate.y.isZero || !candidate.z.isZero {
                return candidate
            }

            let value3 = property.float3Value
            let fallbackCandidate = SIMD3<Float>(value3.x, value3.y, value3.z)
            if !fallbackCandidate.x.isZero || !fallbackCandidate.y.isZero || !fallbackCandidate.z.isZero {
                return fallbackCandidate
            }

            return defaultValue
        }

        func baseColorFactor() -> SIMD3<Float> {
            guard textureProperty(with: .baseColor) == nil else {
                return SIMD3<Float>(repeating: 1)
            }

            return colorFactor(for: .baseColor,
                               default: SIMD3<Float>(repeating: 1))
        }

        func opacityTexture() -> MTLTexture? {
            guard let property = textureProperty(with: .opacity) else {
                return nil
            }

            let opacitySource = property.textureSamplerValue?.texture
            let baseColorSource = textureProperty(with: .baseColor)?
                .textureSamplerValue?
                .texture
            if let opacitySource,
               let baseColorSource,
               opacitySource === baseColorSource {
                return nil
            }

            return texture(from: opacitySource, semantic: .opacity)
        }

        let hasOpacityProperty = !properties(with: .opacity).isEmpty

        func texturePropertyValue(with semantic: MDLMaterialSemantic) -> MTLTexture? {
            guard let property = textureProperty(with: semantic) else {
                return nil
            }

            return texture(from: property.textureSamplerValue?.texture,
                           semantic: semantic)
        }

        baseColor = texturePropertyValue(with: .baseColor)
        normal = texturePropertyValue(with: .tangentSpaceNormal)
        roughness = texturePropertyValue(with: .roughness)
        metallic = texturePropertyValue(with: .metallic)
        ambientOcclusion = texturePropertyValue(with: .ambientOcclusion)
        emissive = texturePropertyValue(with: .emission)
        opacity = opacityTexture()
        let hasSeparateOpacityTexture = opacity != nil
        materialUniforms = MaterialUniforms(
            baseColorFactor: baseColorFactor(),
            opacityFactor: scalarFactor(for: .opacity, default: 1),
            roughnessFactor: scalarFactor(for: .roughness, default: 1),
            metallicFactor: scalarFactor(for: .metallic, default: 0),
            ambientOcclusionFactor: scalarFactor(for: .ambientOcclusion, default: 1),
            usesBaseColorAlpha: hasOpacityProperty ? 1 : 0,
            usesOpacityTexture: hasSeparateOpacityTexture ? 1 : 0,
            rimAlphaStrength: 0,
            unlit: 0,
            whiteAlbedo: 0,
            padding: 0
        )
    }
}
