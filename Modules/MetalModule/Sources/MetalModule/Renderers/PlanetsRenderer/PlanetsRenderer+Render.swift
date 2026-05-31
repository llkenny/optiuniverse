//
//  PlanetsRenderer+Render.swift
//  MetalModule
//
//  Created by max on 07.05.2026.
//

import simd

extension PlanetsRenderer {

    private struct RenderSubmesh {
        let loadedMesh: LoadedMesh
        let submeshIndex: Int
    }

    private struct FragmentUniforms {
        var cameraPosition: SIMD3<Float>
        var lightPosition: SIMD3<Float>
        var cartoonShaderIntensity: Float
    }

    func renderPlanet(_ planet: PreparedPlanetRenderPacket,
                      renderPass: RenderPass,
                      configuration: PlanetRenderConfiguration) {
        // Compute screen position of the planet's center
        if renderPass == .opaque {
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

        let renderEncoder = configuration.renderEncoder
        // Set buffers
        renderEncoder.setFragmentSamplerState(samplerState, index: 0)
        var fragmentUniforms = FragmentUniforms(
            cameraPosition: configuration.cameraOffset,
            lightPosition: -configuration.sceneOrigin,
            cartoonShaderIntensity: min(max(configuration.cartoonShaderIntensity, 0), 1)
        )
        renderEncoder.setFragmentBytes(&fragmentUniforms,
                                       length: MemoryLayout<FragmentUniforms>.stride,
                                       index: 0)

        let renderSubmeshes = submeshes(for: planet,
                                        renderPass: renderPass,
                                        cameraPosition: configuration.cameraOffset,
                                        sceneOrigin: configuration.sceneOrigin)

        render(renderSubmeshes: renderSubmeshes,
               planet: planet,
               configuration: configuration,
               renderPass: renderPass)
    }

    private func render(renderSubmeshes: [PlanetsRenderer.RenderSubmesh],
                        planet: PreparedPlanetRenderPacket,
                        configuration: PlanetRenderConfiguration,
                        renderPass: RenderPass) {

        let renderEncoder = configuration.renderEncoder

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
}
