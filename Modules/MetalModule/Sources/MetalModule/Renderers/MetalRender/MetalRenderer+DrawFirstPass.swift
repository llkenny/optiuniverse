//
//  MetalRenderer+DrawFirstPass.swift
//  OptiUniverse
//
//  Created by max on 29.04.2026.
//

import Metal
import simd
import UIKit

extension MetalRenderer {
    enum DrawFirstPassError: Error {
        case noGeometryCommandBuffer, noRenderEncoder
    }
    /// Render scene to MSAA texture and resolve to HDR texture
    func drawFirstPass(msaaColorTexture: MTLTexture,
                       hdrTexture: MTLTexture,
                       depthTexture: MTLTexture,
                       snapshot: PreparedRenderSnapshot?) throws(DrawFirstPassError) {

        guard let geometryCommandBuffer = commandQueue
            .makeCommandBuffer() else {
            throw .noGeometryCommandBuffer
        }
        let hdrDescriptor = makeHdrDescriptor(msaaColorTexture: msaaColorTexture,
                                              hdrTexture: hdrTexture,
                                              depthTexture: depthTexture)

        guard let renderEncoder = geometryCommandBuffer
            .makeRenderCommandEncoder(descriptor: hdrDescriptor) else {
            throw .noRenderEncoder
        }
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setCullMode(.none)

        let renderOrigin = cameraTarget
        let renderViewMatrix = float4x4.lookAt(
            eye: cameraOffset,
            target: .zero,
            up: cameraUp
        )

        let configuration = PlanetRenderConfiguration(snapshot: snapshot,
                                                      renderEncoder: renderEncoder,
                                                      viewMatrix: renderViewMatrix,
                                                      projectionMatrix: projectionMatrix,
                                                      cameraPosition: cameraOffset,
                                                      sceneOrigin: renderOrigin,
                                                      viewportSize: metalView.bounds.size,
                                                      cartoonShaderIntensity: min(max(cartoonShaderIntensity, 0), 1))
        // Render the remaining planets.
        planetsRenderer.renderPlanets(configuration: configuration)
        renderEncoder.endEncoding()

        if let blit = geometryCommandBuffer.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: hdrTexture)
            blit.endEncoding()
        }

        geometryCommandBuffer.commit()

        // Update any label overlays with the latest planet positions
        let positions = planetsRenderer.planetScreenPositions
        labelDelegate?.updatePlanetLabels(positions)
    }

    private func makeHdrDescriptor(msaaColorTexture: MTLTexture,
                                   hdrTexture: MTLTexture,
                                   depthTexture: MTLTexture) -> MTLRenderPassDescriptor {
        let hdrDescriptor = MTLRenderPassDescriptor()
        hdrDescriptor.colorAttachments[0].texture = msaaColorTexture
        hdrDescriptor.colorAttachments[0].resolveTexture = hdrTexture
        hdrDescriptor.colorAttachments[0].loadAction = .clear
        hdrDescriptor.colorAttachments[0].storeAction = .multisampleResolve
        hdrDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        hdrDescriptor.depthAttachment.texture = depthTexture
        hdrDescriptor.depthAttachment.loadAction = .clear
        hdrDescriptor.depthAttachment.storeAction = .dontCare
        hdrDescriptor.depthAttachment.clearDepth = 1.0
        return hdrDescriptor
    }
}
