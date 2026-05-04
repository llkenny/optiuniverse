import Foundation
import CoreGraphics
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
    var alphaGeometryRadius: Float = 0
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

        let textureFactory = TextureFactory(
            material: material,
            textureLoader: MTKTextureLoader(device: device)
        )

        baseColor = textureFactory.texturePropertyValue(with: .baseColor)
        normal = textureFactory.texturePropertyValue(with: .tangentSpaceNormal)
        roughness = textureFactory.texturePropertyValue(with: .roughness)
        metallic = textureFactory.texturePropertyValue(with: .metallic)
        ambientOcclusion = textureFactory.texturePropertyValue(with: .ambientOcclusion)
        emissive = textureFactory.texturePropertyValue(with: .emission)
        opacity = textureFactory.opacityTexture()
        let hasSeparateOpacityTexture = opacity != nil
        let shouldUseBaseColorAlpha = textureFactory.usesBaseColorAlpha(hasSeparateOpacityTexture: hasSeparateOpacityTexture)
        materialUniforms = MaterialUniforms(
            baseColorFactor: textureFactory.baseColorFactor(),
            opacityFactor: textureFactory.scalarFactor(for: .opacity, default: 1),
            roughnessFactor: textureFactory.scalarFactor(for: .roughness, default: 1),
            metallicFactor: textureFactory.scalarFactor(for: .metallic, default: 0),
            ambientOcclusionFactor: textureFactory.scalarFactor(for: .ambientOcclusion, default: 1),
            usesBaseColorAlpha: shouldUseBaseColorAlpha ? 1 : 0,
            usesOpacityTexture: hasSeparateOpacityTexture ? 1 : 0,
            rimAlphaStrength: 0,
            unlit: 0,
            whiteAlbedo: 0,
            alphaGeometryRadius: 0
        )
    }
}
