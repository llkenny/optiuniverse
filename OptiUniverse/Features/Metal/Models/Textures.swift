import MetalKit

struct MaterialUniforms {
    var roughnessFactor: Float = 1
    var metallicFactor: Float = 0
    var ambientOcclusionFactor: Float = 1
    var padding: Float = 0
}

struct Textures {
    var baseColor: MTLTexture?
    var normal: MTLTexture?
    var roughness: MTLTexture?
    var metallic: MTLTexture?
    var ambientOcclusion: MTLTexture?
    var emissive: MTLTexture?
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
        materialUniforms = MaterialUniforms(
            roughnessFactor: scalarFactor(for: .roughness, default: 1),
            metallicFactor: scalarFactor(for: .metallic, default: 0),
            ambientOcclusionFactor: scalarFactor(for: .ambientOcclusion, default: 1),
            padding: 0
        )
    }
}
