//
//  MetalRenderer+DrawSecondPass.swift
//  OptiUniverse
//
//  Created by max on 29.04.2026.
//

import Metal
import QuartzCore

extension MetalRenderer {
    /// Post-process to drawable using MSAA and resolve to the drawable
    func drawSecondPass(postfxMsaaTexture: MTLTexture,
                        drawable: CAMetalDrawable,
                        hdrTexture: MTLTexture) {
        guard let postfxCommandBuffer = commandQueue.makeCommandBuffer() else { return }
        let finalDescriptor = makeFinalDescriptor(postfxMsaaTexture: postfxMsaaTexture,
                                                  drawable: drawable)

        configureQuadEncoder(postfxCommandBuffer: postfxCommandBuffer,
                             finalDescriptor: finalDescriptor,
                             postfxPipelineState: postfxPipelineState,
                             hdrTexture: hdrTexture,
                             postFXParams: &postFXParams)

        postfxCommandBuffer.present(drawable)
        postfxCommandBuffer.commit()
    }

    private func makeFinalDescriptor(postfxMsaaTexture: MTLTexture,
                                     drawable: CAMetalDrawable) -> MTLRenderPassDescriptor {
        let finalDescriptor = MTLRenderPassDescriptor()
        finalDescriptor.colorAttachments[0].texture = postfxMsaaTexture
        finalDescriptor.colorAttachments[0].resolveTexture = drawable.texture
        finalDescriptor.colorAttachments[0].loadAction = .clear
        finalDescriptor.colorAttachments[0].storeAction = .multisampleResolve
        finalDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        return finalDescriptor
    }

    private func configureQuadEncoder(postfxCommandBuffer: MTLCommandBuffer,
                                      finalDescriptor: MTLRenderPassDescriptor,
                                      postfxPipelineState: MTLRenderPipelineState,
                                      hdrTexture: MTLTexture,
                                      postFXParams: inout PostFXParams) {
        guard let quadEncoder = postfxCommandBuffer.makeRenderCommandEncoder(descriptor: finalDescriptor) else {
            return
        }
        quadEncoder.setRenderPipelineState(postfxPipelineState)
        quadEncoder.setFragmentTexture(hdrTexture, index: 0)
        quadEncoder.setFragmentTexture(lensDirtTexture, index: 1)
        quadEncoder.setFragmentBytes(&postFXParams, length: MemoryLayout<PostFXParams>.stride, index: 0)
        quadEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        quadEncoder.endEncoding()
    }
}
