//
//  Textures.swift
//  OptiUniverse
//
//  Created by max on 05.08.2025.
//

import MetalKit

struct Textures {
    var baseColor: MTLTexture?
}

extension Textures {
    init(material: MDLMaterial?, device: MTLDevice) {
        func property(with semantic: MDLMaterialSemantic)
        -> MTLTexture? {
            guard let property = material?.property(with: semantic),
                  let fileUrl = property.urlValue,
                  let texture =
                    try? loadTexture(url: fileUrl, device: device)
            else { return nil }
            return texture
        }
        baseColor = property(with: MDLMaterialSemantic.baseColor)
    }
    
    func loadTexture(url: URL, device: MTLDevice) throws -> MTLTexture? {
        // 1
        let textureLoader = MTKTextureLoader(device: device)
        
        // 2
        let textureLoaderOptions: [MTKTextureLoader.Option: Any] =
        [.origin: MTKTextureLoader.Origin.bottomLeft]
        
        let texture =
        try textureLoader.newTexture(URL: url,
                                     options: textureLoaderOptions)
        print("loaded texture: \(url.lastPathComponent)")
        return texture
    }
}
