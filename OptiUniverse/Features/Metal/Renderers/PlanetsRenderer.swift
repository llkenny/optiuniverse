//
//  PlanetsRenderer.swift
//  OptiUniverse
//
//  Created by max on 05.08.2025.
//

import MetalKit
import QuartzCore
import simd

// swiftlint:disable type_body_length
final class PlanetsRenderer {
    private enum RenderPass {
        case opaque
        case transparent
    }

    private struct RenderSubmesh {
        let loadedMesh: LoadedMesh
        let submeshIndex: Int
    }

    private struct FragmentUniforms {
        var cameraPosition: SIMD3<Float>
        var lightPosition: SIMD3<Float>
    }

    private static let colorPixelFormat: MTLPixelFormat = .rgba16Float
    private static let depthPixelFormat: MTLPixelFormat = .depth32Float

    private let device: MTLDevice
    var pipelineState: MTLRenderPipelineState!
    private var samplerState: MTLSamplerState!
    private let opaqueDepthStencilState: MTLDepthStencilState
    private let transparentDepthStencilState: MTLDepthStencilState

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
        self.opaqueDepthStencilState = Self.makeDepthStencilState(device: device,
                                                                  writesDepth: true)
        self.transparentDepthStencilState = Self.makeDepthStencilState(device: device,
                                                                       writesDepth: false)

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

    private static func makeDepthStencilState(device: MTLDevice,
                                              writesDepth: Bool) -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .less
        descriptor.isDepthWriteEnabled = writesDepth
        guard let state = device.makeDepthStencilState(descriptor: descriptor) else {
            fatalError("Failed to create planet depth stencil state")
        }
        return state
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
        samplerDescriptor.maxAnisotropy = 8
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

    func renderPlanets(configuration: PlanetRenderConfiguration) {
        planetScreenPositions.removeAll()
        planetWorldPositions.removeAll()

        guard let snapshot = configuration.snapshot else { return }

        configuration.renderEncoder.setRenderPipelineState(pipelineState)
        configuration.renderEncoder.setDepthStencilState(opaqueDepthStencilState)
        for planet in snapshot.planets {
            renderPlanet(planet,
                         renderPass: .opaque,
                         configuration: configuration)
        }

        let cameraWorldPosition = configuration.sceneOrigin + configuration.cameraPosition
        let transparentPlanets = snapshot.planets
            .filter { planet in
                hasTransparentSubmesh(in: planet)
            }
            .sorted {
                simd_distance_squared($0.worldPosition, cameraWorldPosition) >
                simd_distance_squared($1.worldPosition, cameraWorldPosition)
            }

        configuration.renderEncoder.setDepthStencilState(transparentDepthStencilState)
        for planet in transparentPlanets {
            renderPlanet(planet,
                         renderPass: .transparent,
                         configuration: configuration)
        }
    }

    // TODO: Make orbit radius SIM3
    private func renderPlanet(_ planet: PreparedPlanetRenderPacket,
                              renderPass: RenderPass,
                              configuration: PlanetRenderConfiguration) {
        // Compute screen position of the planet's center
        if renderPass == .opaque {
            planetWorldPositions[planet.planetName] = planet.worldPosition
            let localPosition4 = SIMD4<Float>(planet.worldPosition - configuration.sceneOrigin, 1)
            let clipPosition = configuration.projectionMatrix * configuration.viewMatrix * localPosition4
            // clip-space `w` is positive for objects in front of the camera in our
            // coordinate system. Ignore objects with non-positive `w` values to
            // skip planets behind the camera while also avoiding divide-by-zero.
            if clipPosition.w > 0 {
                let ndc = clipPosition / clipPosition.w
                if abs(ndc.x) <= 1, abs(ndc.y) <= 1, ndc.z >= 0, ndc.z <= 1 {
                    let xValue = (ndc.x + 1) * 0.5 * Float(configuration.viewportSize.width)
                    // Metal's projection matrix already flips the Y axis, so
                    // screen-space Y grows downward. Use `ndc.y + 1` instead of
                    // `1 - ndc.y` to avoid mirroring label positions vertically.
                    let yValue = (ndc.y + 1) * 0.5 * Float(configuration.viewportSize.height)
                    planetScreenPositions[planet.planetName] = SIMD2<Float>(xValue, yValue)
                }
            }
        }

        // TODO:
        // Elliptical orbit example
        //        let eccentricity: Float = 0.1 // 0 for circular
        //        let ellipticalDistance = distance * (1 - eccentricity * eccentricity) / (1 + eccentricity * cos(angle))

        let renderEncoder = configuration.renderEncoder
        // Set buffers
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        var fragmentUniforms = FragmentUniforms(
            cameraPosition: configuration.cameraPosition,
            lightPosition: -configuration.sceneOrigin
        )
        renderEncoder.setFragmentBytes(&fragmentUniforms,
                                       length: MemoryLayout<FragmentUniforms>.stride,
                                       index: 0)

        let renderSubmeshes = submeshes(for: planet,
                                        renderPass: renderPass,
                                        cameraPosition: configuration.cameraPosition,
                                        sceneOrigin: configuration.sceneOrigin)

        for renderSubmesh in renderSubmeshes {
            let loadedMesh = renderSubmesh.loadedMesh
            let mesh = loadedMesh.mesh
            guard let submesh = mesh.submeshes[safe: renderSubmesh.submeshIndex] else {
                continue
            }

            var modelMatrix = localModelMatrix(for: planet,
                                               loadedMesh: loadedMesh,
                                               sceneOrigin: configuration.sceneOrigin)
            var mvpMatrix = configuration.projectionMatrix * configuration.viewMatrix * modelMatrix
            renderEncoder.setVertexBytes(&mvpMatrix,
                                         length: MemoryLayout<float4x4>.stride,
                                         index: 5)
            renderEncoder.setVertexBytes(&modelMatrix,
                                         length: MemoryLayout<float4x4>.stride,
                                         index: 6)
            var worldModelMatrixForShader = modelMatrix
            renderEncoder.setVertexBytes(&worldModelMatrixForShader,
                                         length: MemoryLayout<float4x4>.stride,
                                         index: 7)

            for (bufferIndex, vertexBuffer) in mesh.vertexBuffers.enumerated() {
                renderEncoder.setVertexBuffer(vertexBuffer.buffer,
                                              offset: vertexBuffer.offset,
                                              index: bufferIndex)
            }

            let textures = loadedMesh.textures[safe: renderSubmesh.submeshIndex]
            var materialUniforms = materialUniforms(for: planet,
                                                    loadedMesh: loadedMesh,
                                                    renderPass: renderPass,
                                                    textures: textures)
            renderEncoder.setFragmentTexture(textures?.baseColor, index: 0)
            renderEncoder.setFragmentTexture(textures?.normal, index: 1)
            renderEncoder.setFragmentTexture(textures?.emissive, index: 2)
            renderEncoder.setFragmentTexture(textures?.roughness, index: 3)
            renderEncoder.setFragmentTexture(textures?.metallic, index: 4)
            renderEncoder.setFragmentTexture(textures?.ambientOcclusion, index: 5)
            renderEncoder.setFragmentTexture(textures?.opacity, index: 6)
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

    private func submeshes(for planet: PreparedPlanetRenderPacket,
                           renderPass: RenderPass,
                           cameraPosition: SIMD3<Float>,
                           sceneOrigin: SIMD3<Float>) -> [RenderSubmesh] {
        let renderSubmeshes = planet.meshes.flatMap { loadedMesh in
            loadedMesh.mesh.submeshes.indices.compactMap { submeshIndex -> RenderSubmesh? in
                if alphaGeometryRadius(for: planet,
                                       loadedMesh: loadedMesh) > 0 {
                    return RenderSubmesh(loadedMesh: loadedMesh,
                                         submeshIndex: submeshIndex)
                }

                let isTransparent = isTransparentSubmesh(loadedMesh,
                                                         submeshIndex: submeshIndex,
                                                         planet: planet)
                guard (renderPass == .transparent) == isTransparent else {
                    return nil
                }

                return RenderSubmesh(loadedMesh: loadedMesh,
                                     submeshIndex: submeshIndex)
            }
        }

        guard renderPass == .transparent else {
            return renderSubmeshes
        }

        return renderSubmeshes.sorted {
            let lhsDistance = simd_distance_squared(meshCenter(for: planet,
                                                               loadedMesh: $0.loadedMesh,
                                                               sceneOrigin: sceneOrigin),
                                                    cameraPosition)
            let rhsDistance = simd_distance_squared(meshCenter(for: planet,
                                                               loadedMesh: $1.loadedMesh,
                                                               sceneOrigin: sceneOrigin),
                                                    cameraPosition)
            if abs(lhsDistance - rhsDistance) > 0.0001 {
                return lhsDistance > rhsDistance
            }

            let lhsRadius = effectiveRenderRadius(for: planet,
                                                  loadedMesh: $0.loadedMesh)
            let rhsRadius = effectiveRenderRadius(for: planet,
                                                  loadedMesh: $1.loadedMesh)
            if abs(lhsRadius - rhsRadius) > 0.0001 {
                return lhsRadius < rhsRadius
            }

            return $0.submeshIndex > $1.submeshIndex
        }
    }

    private func localModelMatrix(for planet: PreparedPlanetRenderPacket,
                                  loadedMesh: LoadedMesh,
                                  sceneOrigin: SIMD3<Float>) -> float4x4 {
        var meshScale = planet.normalizedScale
        if loadedMesh.boundsRadius > 0,
           loadedMesh.boundsRadius < planet.primaryMeshRadius * 0.8,
           isTransparentCompanionMesh(loadedMesh) {
            meshScale = (planet.primaryMeshRadius * planet.normalizedScale * 1.02) / loadedMesh.boundsRadius
        }

        var matrix = planet.baseModelMatrix
        * float4x4.makeScale(SIMD3<Float>(repeating: meshScale))
        var translation = matrix.columns.3
        translation.x = planet.worldPosition.x - sceneOrigin.x
        translation.y = planet.worldPosition.y - sceneOrigin.y
        translation.z = planet.worldPosition.z - sceneOrigin.z
        matrix.columns.3 = translation
        return matrix
    }

    private func meshCenter(for planet: PreparedPlanetRenderPacket,
                            loadedMesh: LoadedMesh,
                            sceneOrigin: SIMD3<Float>) -> SIMD3<Float> {
        let modelMatrix = localModelMatrix(for: planet,
                                           loadedMesh: loadedMesh,
                                           sceneOrigin: sceneOrigin)
        let center = modelMatrix * SIMD4<Float>(loadedMesh.boundsCenter, 1)
        return SIMD3<Float>(center.x, center.y, center.z)
    }

    private func effectiveRenderRadius(for planet: PreparedPlanetRenderPacket,
                                       loadedMesh: LoadedMesh) -> Float {
        if loadedMesh.boundsRadius > 0,
           loadedMesh.boundsRadius < planet.primaryMeshRadius * 0.8,
           isTransparentCompanionMesh(loadedMesh) {
            return planet.primaryMeshRadius * planet.normalizedScale * 1.02
        }

        return loadedMesh.boundsRadius * planet.normalizedScale
    }

    private func isTransparentCompanionMesh(_ loadedMesh: LoadedMesh) -> Bool {
        isNamedTransparentMesh(loadedMesh) ||
        loadedMesh.textures.contains {
            $0.materialUniforms.usesBaseColorAlpha > 0.5 ||
            $0.materialUniforms.usesOpacityTexture > 0.5
        }
    }

    private func hasTransparentSubmesh(in planet: PreparedPlanetRenderPacket) -> Bool {
        planet.meshes.contains { loadedMesh in
            loadedMesh.mesh.submeshes.indices.contains { submeshIndex in
                isTransparentSubmesh(loadedMesh,
                                     submeshIndex: submeshIndex,
                                     planet: planet)
            }
        }
    }

    private func isTransparentSubmesh(_ loadedMesh: LoadedMesh,
                                      submeshIndex: Int,
                                      planet: PreparedPlanetRenderPacket) -> Bool {
        let textures = loadedMesh.textures[safe: submeshIndex]
        let uniforms = materialUniforms(for: planet,
                                        loadedMesh: loadedMesh,
                                        renderPass: .transparent,
                                        textures: textures)
        return isTransparentMaterial(uniforms) ||
        (textures == nil && isNamedTransparentMesh(loadedMesh))
    }

    private func materialUniforms(for planet: PreparedPlanetRenderPacket,
                                  loadedMesh: LoadedMesh,
                                  renderPass: RenderPass,
                                  textures: Textures?) -> MaterialUniforms {
        var materialUniforms = textures?.materialUniforms ?? MaterialUniforms()
        let meshName = loadedMesh.mesh.name
        if planet.planetName == "Sun" {
            materialUniforms.unlit = 1
        }
        if meshName.localizedCaseInsensitiveContains("SunCorona") {
            materialUniforms.rimAlphaStrength = 2.5
        }
        if meshName.localizedCaseInsensitiveContains("Atmosphere") {
            materialUniforms.opacityFactor *= 0.58
        }
        if meshName.localizedCaseInsensitiveContains("Nuvem") ||
            meshName.localizedCaseInsensitiveContains("Cloud") {
            materialUniforms.whiteAlbedo = 1
            materialUniforms.opacityFactor *= 0.58
            materialUniforms.ambientOcclusionFactor = 1
        }
        let alphaGeometryRadius = alphaGeometryRadius(for: planet,
                                                      loadedMesh: loadedMesh)
        if alphaGeometryRadius > 0 {
            materialUniforms.usesOpacityTexture = 0
            switch renderPass {
            case .opaque:
                materialUniforms.usesBaseColorAlpha = 0
                materialUniforms.alphaGeometryRadius = -alphaGeometryRadius
            case .transparent:
                materialUniforms.usesBaseColorAlpha = 1
                materialUniforms.alphaGeometryRadius = alphaGeometryRadius
            }
        }
        return materialUniforms
    }

    private func alphaGeometryRadius(for planet: PreparedPlanetRenderPacket,
                                     loadedMesh: LoadedMesh) -> Float {
        guard planet.planetName == "Saturn" || planet.planetName == "Uranus",
              loadedMesh.mesh.name == planet.meshes.first?.mesh.name,
              loadedMesh.mesh.submeshes.count == 1,
              loadedMesh.boundsRadius > 0 else {
            return 0
        }

        // The current Saturn/Uranus USD meshes combine the sphere and rings in
        // one submesh. Split near the gap between sphere vertices and ring
        // vertices so each pass can use the right alpha/depth behavior.
        switch planet.planetName {
        case "Saturn":
            return loadedMesh.boundsRadius * 0.32
        case "Uranus":
            return loadedMesh.boundsRadius * 0.47
        default:
            return 0
        }
    }

    private func isTransparentMaterial(_ materialUniforms: MaterialUniforms) -> Bool {
        materialUniforms.usesBaseColorAlpha > 0.5 ||
        materialUniforms.usesOpacityTexture > 0.5 ||
        materialUniforms.opacityFactor < 0.999 ||
        materialUniforms.rimAlphaStrength > 0.5
    }

    private func isNamedTransparentMesh(_ loadedMesh: LoadedMesh) -> Bool {
        let meshName = loadedMesh.mesh.name
        return meshName.localizedCaseInsensitiveContains("Atmosphere") ||
        meshName.localizedCaseInsensitiveContains("Cloud") ||
        meshName.localizedCaseInsensitiveContains("Nuvem") ||
        meshName.localizedCaseInsensitiveContains("Corona")
    }
}
// swiftlint:enable type_body_length

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
