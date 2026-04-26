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

        func scalarProperty(with semantic: MDLMaterialSemantic) -> MDLMaterialProperty? {
            properties(with: semantic).first { $0.textureSamplerValue?.texture == nil }
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
            guard let property = scalarProperty(with: semantic) else {
                return defaultValue
            }

            return colorFactor(from: property, default: defaultValue)
        }

        func colorFactor(from property: MDLMaterialProperty,
                         default defaultValue: SIMD3<Float>) -> SIMD3<Float> {
            switch property.type {
            case .float:
                return SIMD3<Float>(repeating: property.floatValue)
            case .float3:
                let value = property.float3Value
                return SIMD3<Float>(value.x, value.y, value.z)
            case .float4, .color:
                let value = property.float4Value
                return SIMD3<Float>(value.x, value.y, value.z)
            default:
                return defaultValue
            }
        }

        func baseColorFactor() -> SIMD3<Float> {
            guard let property = scalarProperty(with: .baseColor) else {
                return SIMD3<Float>(repeating: 1)
            }

            if textureProperty(with: .baseColor) != nil,
               isModelIODefaultBaseColorFactor(property) {
                return SIMD3<Float>(repeating: 1)
            }

            return colorFactor(from: property,
                               default: SIMD3<Float>(repeating: 1))
        }

        func isModelIODefaultBaseColorFactor(_ property: MDLMaterialProperty) -> Bool {
            guard property.name == "baseColor",
                  property.type == .float3 else {
                return false
            }

            let value = property.float3Value
            let defaultValue: Float = 0.18
            let epsilon: Float = 0.0001
            return abs(value.x - defaultValue) < epsilon &&
                abs(value.y - defaultValue) < epsilon &&
                abs(value.z - defaultValue) < epsilon
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
               texturesShareSource(opacitySource, baseColorSource) {
                return nil
            }

            return texture(from: opacitySource, semantic: .opacity)
        }

        func usesBaseColorAlpha(hasSeparateOpacityTexture: Bool) -> Bool {
            if hasSeparateOpacityTexture {
                return false
            }

            guard
                let property = textureProperty(with: .baseColor),
                let baseColorSource = property.textureSamplerValue?.texture
            else {
                return false
            }

            if let opacitySource = textureProperty(with: .opacity)?
                .textureSamplerValue?
                .texture,
               texturesShareSource(opacitySource, baseColorSource) {
                return textureHasVisibleAlpha(baseColorSource)
            }

            return textureHasVisibleAlpha(baseColorSource)
        }

        func texturesShareSource(_ lhs: MDLTexture, _ rhs: MDLTexture) -> Bool {
            if lhs === rhs {
                return true
            }

            let lhsIdentifier = textureURLIdentifier(lhs)
            let rhsIdentifier = textureURLIdentifier(rhs)
            if let lhsIdentifier, let rhsIdentifier {
                guard lhsIdentifier == rhsIdentifier else {
                    return false
                }
                return true
            }

            return texturesHaveMatchingProbe(lhs, rhs)
        }

        func textureURLIdentifier(_ texture: MDLTexture) -> String? {
            if let urlTexture = texture as? MDLURLTexture {
                let url = urlTexture.url
                if url.isFileURL {
                    return "url:\(url.standardizedFileURL.path)"
                }
                return "url:\(url.absoluteString)"
            }

            return nil
        }

        func texturesHaveMatchingProbe(_ lhs: MDLTexture, _ rhs: MDLTexture) -> Bool {
            guard lhs.dimensions.x == rhs.dimensions.x,
                  lhs.dimensions.y == rhs.dimensions.y,
                  lhs.channelCount == rhs.channelCount,
                  lhs.channelEncoding == rhs.channelEncoding,
                  let lhsProbe = normalizedRGBAProbe(for: lhs, maxDimension: 32),
                  let rhsProbe = normalizedRGBAProbe(for: rhs, maxDimension: 32) else {
                return false
            }

            return lhsProbe == rhsProbe
        }

        func textureHasVisibleAlpha(_ mdlTexture: MDLTexture) -> Bool {
            guard mdlTexture.hasAlphaValues,
                  let pixels = normalizedRGBAProbe(for: mdlTexture, maxDimension: 128) else {
                return false
            }

            var nonOpaqueCount = 0
            let pixelCount = pixels.count / 4
            var alphaIndex = 3
            while alphaIndex < pixels.count {
                if pixels[alphaIndex] < 255 {
                    nonOpaqueCount += 1
                }
                alphaIndex += 4
            }

            let alphaCoverage = Float(nonOpaqueCount) / Float(pixelCount)
            return alphaCoverage >= 0.02
        }

        func normalizedRGBAProbe(for mdlTexture: MDLTexture,
                                 maxDimension: Int) -> [UInt8]? {
            guard mdlTexture.channelCount >= 4,
                  let unmanagedImage = mdlTexture.imageFromTexture() else {
                return nil
            }

            // `imageFromTexture` is not annotated/created as a retained Core
            // Foundation result, so taking retained ownership over-releases it.
            let image = unmanagedImage.takeUnretainedValue()
            let width = image.width
            let height = image.height
            guard width > 0, height > 0 else {
                return nil
            }

            let scale = min(1, Double(maxDimension) / Double(max(width, height)))
            let probeWidth = max(1, Int((Double(width) * scale).rounded(.up)))
            let probeHeight = max(1, Int((Double(height) * scale).rounded(.up)))
            let bytesPerPixel = 4
            let bytesPerRow = probeWidth * bytesPerPixel
            var pixels = [UInt8](repeating: 0, count: probeHeight * bytesPerRow)
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue |
                CGBitmapInfo.byteOrder32Big.rawValue
            guard let context = CGContext(data: &pixels,
                                          width: probeWidth,
                                          height: probeHeight,
                                          bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow,
                                          space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: bitmapInfo) else {
                return nil
            }

            context.draw(image, in: CGRect(x: 0,
                                           y: 0,
                                           width: probeWidth,
                                           height: probeHeight))

            return pixels
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
        opacity = opacityTexture()
        let hasSeparateOpacityTexture = opacity != nil
        let shouldUseBaseColorAlpha = usesBaseColorAlpha(hasSeparateOpacityTexture: hasSeparateOpacityTexture)
        materialUniforms = MaterialUniforms(
            baseColorFactor: baseColorFactor(),
            opacityFactor: scalarFactor(for: .opacity, default: 1),
            roughnessFactor: scalarFactor(for: .roughness, default: 1),
            metallicFactor: scalarFactor(for: .metallic, default: 0),
            ambientOcclusionFactor: scalarFactor(for: .ambientOcclusion, default: 1),
            usesBaseColorAlpha: shouldUseBaseColorAlpha ? 1 : 0,
            usesOpacityTexture: hasSeparateOpacityTexture ? 1 : 0,
            rimAlphaStrength: 0,
            unlit: 0,
            whiteAlbedo: 0,
            alphaGeometryRadius: 0
        )
    }
}
