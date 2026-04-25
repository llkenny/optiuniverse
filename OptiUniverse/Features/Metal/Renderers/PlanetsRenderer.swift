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
    private static let colorPixelFormat: MTLPixelFormat = .rgba16Float
    private static let depthPixelFormat: MTLPixelFormat = .depth32Float

    private let device: MTLDevice
    var pipelineState: MTLRenderPipelineState!
    private var samplerState: MTLSamplerState!
    
    private var time: Float = 0
    var lastUpdateTime = CACurrentMediaTime()
    
    /// Screen-space positions of planet centers, updated each frame.
    /// Keys are planet names, values are pixel coordinates in the viewport.
    var planetScreenPositions: [String: SIMD2<Float>] = [:]
    
    /// World-space positions of planet centers, updated each frame.
    /// Keys are planet names, values are coordinates in the scene space.
    var planetWorldPositions: [String: SIMD3<Float>] = [:]
    
    init(device: MTLDevice, sampleCount: Int) {
        self.device = device
        
        pipelineState = makePipelineState(fragmentFunction: "fragment_main",
                                          sampleCount: sampleCount)
        samplerState = makeSamplerState()
    }
    
    /// Current simulation time used for planet animations.
    var currentTime: Float { time }
    
    /// Builds a render pipeline for the given fragment function.
    ///
    /// - Parameter fragmentFunction: The name of the fragment shader function.
    /// - Returns: A configured `MTLRenderPipelineState`.
    private func makePipelineState(fragmentFunction: String,
                                   sampleCount: Int) -> MTLRenderPipelineState {
        let library = device.makeDefaultLibrary()!
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.rasterSampleCount = sampleCount
        descriptor.colorAttachments[0].pixelFormat = Self.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        descriptor.depthAttachmentPixelFormat = Self.depthPixelFormat
        descriptor.vertexFunction = library.makeFunction(name: "vertex_main")
        descriptor.fragmentFunction = library.makeFunction(name: fragmentFunction)
        descriptor.vertexDescriptor = Self.makeVertexDescriptor()
        
        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create pipeline state: \(error)")
        }
    }
    
    /// Creates the shared vertex descriptor for planet rendering.
    private static func makeVertexDescriptor() -> MTLVertexDescriptor {
        let vertexDescriptor = MTLVertexDescriptor()
        
        // Position (attribute 0)
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // Normal (attribute 1)
        vertexDescriptor.attributes[1].format = .float3
        vertexDescriptor.attributes[1].offset = 0
        vertexDescriptor.attributes[1].bufferIndex = 1
        
        // Texture coordinates (attribute 2)
        vertexDescriptor.attributes[2].format = .float2
        vertexDescriptor.attributes[2].offset = 0
        vertexDescriptor.attributes[2].bufferIndex = 2

        // Tangent (attribute 3)
        vertexDescriptor.attributes[3].format = .float4
        vertexDescriptor.attributes[3].offset = 0
        vertexDescriptor.attributes[3].bufferIndex = 3
        
        // Layout
        vertexDescriptor.layouts[0].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[1].stride = MemoryLayout<SIMD3<Float>>.stride
        vertexDescriptor.layouts[2].stride = MemoryLayout<SIMD2<Float>>.stride
        vertexDescriptor.layouts[3].stride = MemoryLayout<SIMD4<Float>>.stride
        return vertexDescriptor
    }
    
    private func makeSamplerState() -> MTLSamplerState {
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.sAddressMode = .repeat
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        return device.makeSamplerState(descriptor: samplerDescriptor)!
    }
    
    /// Advances the internal time accumulator and returns the time delta.
    /// Should be called once per frame before rendering so other systems can
    /// use the updated time (e.g. camera following).
    func advanceTime() -> Float {
        let currentTime = CACurrentMediaTime()
        let delta = Float(currentTime - lastUpdateTime)
        lastUpdateTime = currentTime
        time += delta
        return delta
    }
    
    func renderPlanets(snapshot: PreparedRenderSnapshot?,
                       with renderEncoder: MTLRenderCommandEncoder,
                       viewMatrix: float4x4,
                       projectionMatrix: float4x4,
                       cameraPosition: SIMD3<Float>,
                       sceneOrigin: SIMD3<Float>,
                       viewportSize: CGSize) {
        planetScreenPositions.removeAll()
        planetWorldPositions.removeAll()

        guard let snapshot else { return }

        for planet in snapshot.planets {
            renderEncoder.setRenderPipelineState(pipelineState)
            renderPlanet(planet,
                         with: renderEncoder,
                         cameraPosition: cameraPosition,
                         viewMatrix: viewMatrix,
                         projectionMatrix: projectionMatrix,
                         sceneOrigin: sceneOrigin,
                         viewportSize: viewportSize)
        }
    }
    
    // TODO: Make orbit radius SIM3
    private func renderPlanet(_ planet: PreparedPlanetRenderPacket,
                              with renderEncoder: MTLRenderCommandEncoder,
                              cameraPosition: SIMD3<Float>,
                              viewMatrix: float4x4,
                              projectionMatrix: float4x4,
                              sceneOrigin: SIMD3<Float>,
                              viewportSize: CGSize) {
        let sceneOffsetMatrix = float4x4.makeTranslation(-sceneOrigin)
        var modelMatrix = sceneOffsetMatrix * planet.worldModelMatrix
        
        var mvpMatrix = projectionMatrix * viewMatrix * modelMatrix
        
        // Compute screen position of the planet's center
        let worldPosition4 = SIMD4<Float>(planet.worldPosition, 1)
        planetWorldPositions[planet.planetName] = planet.worldPosition
        let localPosition4 = sceneOffsetMatrix * worldPosition4
        let clipPosition = projectionMatrix * viewMatrix * localPosition4
        // clip-space `w` is positive for objects in front of the camera in our
        // coordinate system. Ignore objects with non-positive `w` values to
        // skip planets behind the camera while also avoiding divide-by-zero.
        if clipPosition.w > 0 {
            let ndc = clipPosition / clipPosition.w
            if abs(ndc.x) <= 1, abs(ndc.y) <= 1, ndc.z >= 0, ndc.z <= 1 {
                let x = (ndc.x + 1) * 0.5 * Float(viewportSize.width)
                // Metal's projection matrix already flips the Y axis, so
                // screen-space Y grows downward. Use `ndc.y + 1` instead of
                // `1 - ndc.y` to avoid mirroring label positions vertically.
                let y = (ndc.y + 1) * 0.5 * Float(viewportSize.height)
                planetScreenPositions[planet.planetName] = SIMD2<Float>(x, y)
            }
        }
        
        // TODO:
        // Elliptical orbit example
        //        let eccentricity: Float = 0.1 // 0 for circular
        //        let ellipticalDistance = distance * (1 - eccentricity * eccentricity) / (1 + eccentricity * cos(angle))
        
        // Set buffers
        renderEncoder.setVertexBytes(&mvpMatrix,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 5)
        renderEncoder.setVertexBytes(&modelMatrix,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 6)
        var worldModelMatrixForShader = planet.worldModelMatrix
        renderEncoder.setVertexBytes(&worldModelMatrixForShader,
                                     length: MemoryLayout<float4x4>.stride,
                                     index: 7)

        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        var fragmentCameraPosition = cameraPosition
        renderEncoder.setFragmentBytes(&fragmentCameraPosition,
                                       length: MemoryLayout<SIMD3<Float>>.stride,
                                       index: 0)

        for loadedMesh in planet.meshes {
            let mesh = loadedMesh.mesh
            for (bufferIndex, vertexBuffer) in mesh.vertexBuffers.enumerated() {
                renderEncoder.setVertexBuffer(vertexBuffer.buffer,
                                              offset: vertexBuffer.offset,
                                              index: bufferIndex)
            }

            for (index, submesh) in mesh.submeshes.enumerated() {
                let textures = loadedMesh.textures[safe: index]
                var materialUniforms = textures?.materialUniforms ?? MaterialUniforms()
                renderEncoder.setFragmentTexture(textures?.baseColor, index: 0)
                renderEncoder.setFragmentTexture(textures?.normal, index: 1)
                renderEncoder.setFragmentTexture(textures?.emissive, index: 2)
                renderEncoder.setFragmentTexture(textures?.roughness, index: 3)
                renderEncoder.setFragmentTexture(textures?.metallic, index: 4)
                renderEncoder.setFragmentTexture(textures?.ambientOcclusion, index: 5)
                renderEncoder.setFragmentBytes(&materialUniforms,
                                               length: MemoryLayout<MaterialUniforms>.stride,
                                               index: 1)
                renderEncoder.drawIndexedPrimitives(
                    type: .triangle,
                    indexCount: submesh.indexCount,
                    indexType: submesh.indexType,
                    indexBuffer: submesh.indexBuffer.buffer,
                    indexBufferOffset: submesh.indexBuffer.offset
                )
            }
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
