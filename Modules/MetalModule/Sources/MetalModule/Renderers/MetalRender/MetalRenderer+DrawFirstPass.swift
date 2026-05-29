//
//  MetalRenderer+DrawFirstPass.swift
//  OptiUniverse
//
//  Created by max on 29.04.2026.
//

import Metal
import simd
import UIKit

struct SceneRouteRenderState {
    let transfer: TransferOrbitRenderState
    let navigation: NavigationRouteRenderState
}

struct SceneRenderState {
    let cameraSnapshot: SnapshotProvider.CameraSnapshot
    let snapshot: PreparedRenderSnapshot?
    let routes: SceneRouteRenderState
}

extension MetalRenderer {
    enum DrawFirstPassError: Error {
        case noGeometryCommandBuffer, noRenderEncoder
    }
    /// Render scene to MSAA texture and resolve to HDR texture
    func drawFirstPass(msaaColorTexture: MTLTexture,
                       hdrTexture: MTLTexture,
                       depthTexture: MTLTexture,
                       state: SceneRenderState) throws(DrawFirstPassError) {

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

        let renderOrigin = state.cameraSnapshot.sceneOrigin
        let renderViewMatrix = state.cameraSnapshot.renderViewMatrix

        let configuration = PlanetRenderConfiguration(snapshot: state.snapshot,
                                                      renderEncoder: renderEncoder,
                                                      viewMatrix: renderViewMatrix,
                                                      projectionMatrix: state.cameraSnapshot.projectionMatrix,
                                                      cameraPosition: state.cameraSnapshot.cameraPosition,
                                                      sceneOrigin: renderOrigin,
                                                      viewportSize: state.cameraSnapshot.viewportSize,
                                                      cartoonShaderIntensity: min(max(cartoonShaderIntensity, 0), 1))
        starsRenderer.render(renderEncoder: renderEncoder,
                             viewMatrix: renderViewMatrix,
                             projectionMatrix: state.cameraSnapshot.projectionMatrix,
                             sceneOrigin: renderOrigin)
        transferOrbitRenderer.render(state: state.routes.transfer,
                                     renderEncoder: renderEncoder,
                                     viewMatrix: renderViewMatrix,
                                     projectionMatrix: state.cameraSnapshot.projectionMatrix,
                                     sceneOrigin: renderOrigin)
        routeRenderer.render(configuration: RouteRenderConfiguration(
            state: state.routes.navigation,
            renderEncoder: renderEncoder,
            viewMatrix: renderViewMatrix,
            projectionMatrix: state.cameraSnapshot.projectionMatrix,
            sceneOrigin: renderOrigin,
            viewportSize: state.cameraSnapshot.viewportSize
        ))
        // Render the remaining planets.
        planetsRenderer.renderPlanets(configuration: configuration)
        renderEncoder.endEncoding()

        makeBlit(hdrTexture: hdrTexture, geometryCommandBuffer: geometryCommandBuffer)

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

    private func makeBlit(hdrTexture: MTLTexture,
                          geometryCommandBuffer: MTLCommandBuffer) {
        if let blit = geometryCommandBuffer.makeBlitCommandEncoder() {
            blit.generateMipmaps(for: hdrTexture)
            blit.endEncoding()
        }
    }
}
