import MetalKit

struct Textures {
    var baseColor: MTLTexture?
    var normal: MTLTexture?
    var emissive: MTLTexture?
}

extension Textures {
    init(material: MDLMaterial?, device: MTLDevice) {
        let textureLoader = MTKTextureLoader(device: device)

        func textureOptions(for semantic: MDLMaterialSemantic) -> [MTKTextureLoader.Option: Any] {
            [
                .generateMipmaps: NSNumber(booleanLiteral: true),
                .SRGB: NSNumber(booleanLiteral: semantic != .tangentSpaceNormal)
            ]
        }
        
        func texture(from mdlTexture: MDLTexture?,
                     semantic: MDLMaterialSemantic) -> MTLTexture? {
            guard let mdlTexture else {
                return nil
            }

            return try? textureLoader.newTexture(texture: mdlTexture,
                                                 options: textureOptions(for: semantic))
        }

        func property(with semantic: MDLMaterialSemantic) -> MTLTexture? {
            guard let property = material?.property(with: semantic) else {
                return nil
            }

            return texture(from: property.textureSamplerValue?.texture,
                           semantic: semantic)
        }

        baseColor = property(with: MDLMaterialSemantic.baseColor)
        normal = property(with: MDLMaterialSemantic.tangentSpaceNormal)
        emissive = property(with: MDLMaterialSemantic.emission)
    }
}
