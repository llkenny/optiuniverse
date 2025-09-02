//
//  PlanetsRenderer.swift
//  OptiUniverse
//
//  Created by max on 05.08.2025.
//

import MetalKit

final class PlanetsRenderer {
    private let device: MTLDevice
    var pipelineState: MTLRenderPipelineState!
    private var sunPipelineState: MTLRenderPipelineState!
    private var samplerState: MTLSamplerState!
    
    private var mesh: MTKMesh!
    private var texture: MTLTexture!
    
    private var time: Float = 0
    
    // Solar system data
    private var planets: [Planet] = []
    private var planetMeshes: [String: MDLMesh] = [:]
    private var cachedTextures: [String: Textures] = [:]

    init(device: MTLDevice) {
        self.device = device
        pipelineState = makePipelineState(fragmentFunction: "fragment_main")
        sunPipelineState = makePipelineState(fragmentFunction: "fragment_sun")
        samplerState = makeSamplerState()
        planets = SolarSystemLoader.loadPlanets(from: "planets")
    }

    /// Builds a render pipeline for the given fragment function.
    ///
    /// - Parameter fragmentFunction: The name of the fragment shader function.
    /// - Returns: A configured `MTLRenderPipelineState`.
    private func makePipelineState(fragmentFunction: String) -> MTLRenderPipelineState {
        let library = device.makeDefaultLibrary()!

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.vertexFunction = library.makeFunction(name: "vertex_main")
        descriptor.fragmentFunction = library.makeFunction(name: fragmentFunction)
        descriptor.vertexDescriptor = makeVertexDescriptor()

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }

    /// Creates the shared vertex descriptor for planet rendering.
    private func makeVertexDescriptor() -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()

        // Position (attribute 0)
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0

        // Normal (attribute 1)
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = MemoryLayout<Float>.stride * 3
        vertexDescriptor.attributes[1].bufferIndex = 0

        // Texture coordinates (attribute 2)
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = MemoryLayout<Float>.stride * 6
        vertexDescriptor.attributes[2].bufferIndex = 0

        // Layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.stride * 8
        return vertexDescriptor
    }
    
    private func makeSamplerState() -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    private func createTexturedSphere(radius: Float, textureName: String) -> MDLMesh {
        let allocator = MTKMeshBufferAllocator(device: device)
        
        // Create sphere with explicit texture coordinate generation
        let mdlMesh = MDLMesh(
            sphereWithExtent: [1, 1, 1], // TODO: radius, radius, radius
            segments: [20, 20],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: allocator
        )
        
        // Generate texture coordinates
        mdlMesh.addUnwrappedTextureCoordinates(forAttributeNamed: MDLVertexAttributeTextureCoordinate)
        
        // TODO: Load texture here for optimization
        // Load texture
        //        let textureLoader = MTKTextureLoader(device: device)
        //        let textureOptions: [MTKTextureLoader.Option : Any] = [
        //            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
        //            .textureStorageMode: MTLStorageMode.private.rawValue,
        //            .origin: MTKTextureLoader.Origin.bottomLeft.rawValue
        //        ]
        //
        //        texture = try! textureLoader.newTexture(
        //            name: textureName,
        //            scaleFactor: 1.0,
        //            bundle: nil,
        //            options: textureOptions
        //        )
        
        // Create material and assign texture
        let textureURL = Bundle.main.url(forResource: textureName, withExtension: "png")!
        
        let material = MDLMaterial()
        let property = MDLMaterialProperty(
            name: "baseColor",
            semantic: .baseColor,
            url: textureURL
        )
        material.setProperty(property)
        
        // Assign material to submeshes
        for submesh in mdlMesh.submeshes! {
            if let submesh = submesh as? MDLSubmesh {
                submesh.material = material
            }
        }
        
        return mdlMesh
    }
    
    func renderPlanets(with renderEncoder: MTLRenderCommandEncoder,
                       viewMatrix: float4x4,
                       projectionMatrix: float4x4) {
        for planet in planets {
            if planet.name == "Sun" {
                renderEncoder.setRenderPipelineState(sunPipelineState)
            } else {
                renderEncoder.setRenderPipelineState(pipelineState)
            }

            renderPlanet(planet,
                         with: renderEncoder,
                         time: time,
                         viewMatrix: viewMatrix,
                         projectionMatrix: projectionMatrix)
        }
        time += 1
    }
    
    // TODO: Make orbit radius SIM3
    private func renderPlanet(_ planet: Planet,
                              with renderEncoder: MTLRenderCommandEncoder,
                              time: Float,
                              viewMatrix: float4x4,
                              projectionMatrix: float4x4) {
        
        // Get or create mesh
        if planetMeshes[planet.textureName] == nil {
            planetMeshes[planet.textureName] = createTexturedSphere(
                radius: planet.radius,
                textureName: planet.textureName
            )
        }
        guard let mesh = planetMeshes[planet.textureName] else { return }
        
        // 1. Create scaling matrix
        let scaleMatrix = float4x4.makeScale([planet.radius, planet.radius, planet.radius])
        
        // 2. Create translation to orbit distance
        var modelMatrix = float4x4.makeTranslation([Float(planet.distance), 0, 0])
        
        // 3. Apply rotation around sun
        let angle = time * planet.orbitSpeed
        modelMatrix = float4x4.makeRotationZ(angle) * modelMatrix
        
        // 4. Combine with scaling (scale first, then rotate, then translate)
        // TODO: But it different currently
        modelMatrix = modelMatrix * scaleMatrix
        
        // 5. Create MVP matrix
        var mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        
        // TODO:
        // Elliptical orbit example
        //        let eccentricity: Float = 0.1 // 0 for circular
        //        let ellipticalDistance = distance * (1 - eccentricity * eccentricity) / (1 + eccentricity * cos(angle))
        
        //        // Set texture
        if cachedTextures[planet.textureName] == nil {
            let submesh = mesh.submeshes![0] as! MDLSubmesh
            let material = submesh.material!
            let texture = Textures(material: material, device: device)
            cachedTextures[planet.textureName] = texture
        }
        let texture = cachedTextures[planet.textureName]!
        
        let mtkMesh = try! MTKMesh(mesh: mesh, device: device)
        
        // Set buffers
        renderEncoder.setVertexBytes(&mvpMatrix,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 1)
        renderEncoder.setVertexBytes(&modelMatrix,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 2)
        
        renderEncoder.setVertexBuffer(mtkMesh.vertexBuffers[0].buffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(texture.baseColor!, index: 0)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        var t = time
        renderEncoder.setFragmentBytes(&t,
                                       length: MemoryLayout<Float>.stride,
                                       index: 0)
        
        guard let submesh = mtkMesh.submeshes.first else {
            fatalError()
        }
        
        // Draw
        renderEncoder.drawIndexedPrimitives(
            type: .triangle,
            indexCount: submesh.indexCount,
            indexType: submesh.indexType,
            indexBuffer: submesh.indexBuffer.buffer,
            indexBufferOffset: submesh.indexBuffer.offset
        )
    }
}
