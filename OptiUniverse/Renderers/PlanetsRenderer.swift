//
//  PlanetsRenderer.swift
//  OptiUniverse
//
//  Created by max on 05.08.2025.
//

import MetalKit
import QuartzCore
import simd

final class PlanetsRenderer {
    private let device: MTLDevice
    var pipelineState: MTLRenderPipelineState!
    private var sunPipelineState: MTLRenderPipelineState!
    private var samplerState: MTLSamplerState!

    private var time: Float = 0
    var lastUpdateTime = CACurrentMediaTime()
    var exposure: Float = 1.0

    /// Model matrix of the Sun without scaling.
    /// Updated each frame when the Sun is rendered so other renderers
    /// (e.g. debug axes) can match its position and rotation.
    var sunModelMatrix: float4x4 = matrix_identity_float4x4
    
    // Solar system data
    private var planets: [Planet] = []
    private var planetMeshes: [String: MDLMesh] = [:]
    private var cachedTextures: [String: MTLTexture] = [:]

    /// Screen-space positions of planet centers, updated each frame.
    /// Keys are planet names, values are pixel coordinates in the viewport.
    var planetScreenPositions: [String: SIMD2<Float>] = [:]

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
        descriptor.colorAttachments[0].pixelFormat = .rgba16Float
        descriptor.sampleCount = 4
        descriptor.depthAttachmentPixelFormat = .depth32Float
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

        // Create sphere. Model I/O generates proper spherical texture
        // coordinates by default, so we don't need to manually unwrap each
        // face (which caused the texture to appear as repeated rectangles).
        let mdlMesh = MDLMesh(
            sphereWithExtent: [1, 1, 1], // TODO: radius, radius, radius
            segments: [20, 20],
            inwardNormals: false,
            geometryType: .triangles,
            allocator: allocator
        )

        // Load texture with top-left origin and mipmaps to avoid seams
        let textureLoader = MTKTextureLoader(device: device)
        let options: [MTKTextureLoader.Option : Any] = [
            .origin: MTKTextureLoader.Origin.topLeft.rawValue,
            .generateMipmaps: NSNumber(booleanLiteral: true)
        ]
        let textureURL = Bundle.main.url(forResource: textureName, withExtension: "png")!
        let texture = try! textureLoader.newTexture(URL: textureURL, options: options)
        cachedTextures[textureName] = texture

        return mdlMesh
    }
    
    func renderPlanets(with renderEncoder: MTLRenderCommandEncoder,
                       viewMatrix: float4x4,
                       projectionMatrix: float4x4,
                       viewportSize: CGSize) {
        let currentTime = CACurrentMediaTime()
        let delta = Float(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime

        planetScreenPositions.removeAll()

        for planet in planets {
            if planet.name == "Sun" {
                renderEncoder.setRenderPipelineState(sunPipelineState)
            } else {
                renderEncoder.setRenderPipelineState(pipelineState)
            }

            renderPlanet(planet,
                         with: renderEncoder,
                         time: time,
                         delta: delta,
                         viewMatrix: viewMatrix,
                         projectionMatrix: projectionMatrix,
                         viewportSize: viewportSize)
        }
        time += delta
    }

    // TODO: Make orbit radius SIM3
    private func renderPlanet(_ planet: Planet,
                              with renderEncoder: MTLRenderCommandEncoder,
                              time: Float,
                              delta: Float,
                              viewMatrix: float4x4,
                              projectionMatrix: float4x4,
                              viewportSize: CGSize) {
        
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

        // Store Sun transform (without scaling) for debug axes
        if planet.name == "Sun" {
            sunModelMatrix = modelMatrix
        }

        // 4. Combine with scaling (scale first, then rotate, then translate)
        // TODO: But it different currently
        modelMatrix = modelMatrix * scaleMatrix
        
        // 5. Create MVP matrix
        var mvpMatrix = projectionMatrix * viewMatrix * modelMatrix

        // Compute screen position of the planet's center
        let worldPosition = modelMatrix * SIMD4<Float>(0, 0, 0, 1)
        let clipPosition = projectionMatrix * viewMatrix * worldPosition
        if clipPosition.w != 0 {
            let ndc = clipPosition / clipPosition.w
            let x = (ndc.x + 1) * 0.5 * Float(viewportSize.width)
            let y = (1 - ndc.y) * 0.5 * Float(viewportSize.height)
            planetScreenPositions[planet.name] = SIMD2<Float>(x, y)
        }
        
        // TODO:
        // Elliptical orbit example
        //        let eccentricity: Float = 0.1 // 0 for circular
        //        let ellipticalDistance = distance * (1 - eccentricity * eccentricity) / (1 + eccentricity * cos(angle))
        
        // Retrieve cached mesh and texture
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
        renderEncoder.setFragmentTexture(texture, index: 0)
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)

        var t = time
        renderEncoder.setFragmentBytes(&t,
                                       length: MemoryLayout<Float>.stride,
                                       index: 0)

        var d = delta
        renderEncoder.setFragmentBytes(&d,
                                       length: MemoryLayout<Float>.stride,
                                       index: 1)

        var e = exposure
        renderEncoder.setFragmentBytes(&e,
                                       length: MemoryLayout<Float>.stride,
                                       index: 2)
        
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
