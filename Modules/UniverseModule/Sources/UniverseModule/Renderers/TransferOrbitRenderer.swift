//
//  TransferOrbitRenderer.swift
//  UniverseModule
//
//  Created by Codex on 05.05.2026.
//

import Metal
import simd

final class TransferOrbitRenderer {
    private static let colorPixelFormat: MTLPixelFormat = .rgba16Float
    private static let depthPixelFormat: MTLPixelFormat = .depth32Float

    private let device: MTLDevice
    private let pipelineState: MTLRenderPipelineState
    private let depthStencilState: MTLDepthStencilState

    init(device: MTLDevice, sampleCount: Int) {
        self.device = device
        pipelineState = Self.makePipelineState(device: device,
                                               sampleCount: sampleCount)
        depthStencilState = Self.makeDepthStencilState(device: device)
    }

    func render(state: TransferOrbitRenderState,
                renderEncoder: MTLRenderCommandEncoder,
                viewMatrix: float4x4,
                projectionMatrix: float4x4,
                sceneOrigin: SIMD3<Float>) {
        guard let transferOrbit = state.transferOrbit,
              transferOrbit.points.count >= 2 else { return }

        let context = RenderContext(renderEncoder: renderEncoder,
                                    viewMatrix: viewMatrix,
                                    projectionMatrix: projectionMatrix,
                                    sceneOrigin: sceneOrigin)
        renderLine(points: circlePoints(center: transferOrbit.sunPosition,
                                        radius: transferOrbit.earthOrbitRadius),
                   color: SIMD4<Float>(0.26, 0.55, 1.0, 0.72),
                   dashFrequency: 72,
                   dashDuty: 0.48,
                   context: context)
        renderLine(points: circlePoints(center: transferOrbit.sunPosition,
                                        radius: transferOrbit.destinationOrbitRadius),
                   color: SIMD4<Float>(1.0, 0.62, 0.22, 0.72),
                   dashFrequency: 92,
                   dashDuty: 0.48,
                   context: context)
        renderLine(points: transferOrbit.points,
                   color: SIMD4<Float>(0.2, 0.82, 1.0, 1.0),
                   dashFrequency: 0,
                   dashDuty: 1,
                   context: context)
    }

    private func renderLine(points: [SIMD3<Float>],
                            color: SIMD4<Float>,
                            dashFrequency: Float,
                            dashDuty: Float,
                            context: RenderContext) {
        guard points.count >= 2 else { return }

        let vertices = makeVertices(points: points)
        guard let vertexBuffer = device.makeBuffer(bytes: vertices,
                                                   length: MemoryLayout<TransferOrbitVertex>.stride * vertices.count,
                                                   options: .storageModeShared) else {
            return
        }

        var uniforms = TransferOrbitUniforms(
            viewMatrix: context.viewMatrix,
            projectionMatrix: context.projectionMatrix,
            sceneOriginAndOpacity: SIMD4<Float>(context.sceneOrigin.x,
                                                context.sceneOrigin.y,
                                                context.sceneOrigin.z,
                                                0.95),
            color: color,
            dash: SIMD4<Float>(dashFrequency, dashDuty, 0, 0)
        )

        context.renderEncoder.setRenderPipelineState(pipelineState)
        context.renderEncoder.setDepthStencilState(depthStencilState)
        context.renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        context.renderEncoder.setVertexBytes(&uniforms,
                                             length: MemoryLayout<TransferOrbitUniforms>.stride,
                                             index: 1)
        context.renderEncoder.setFragmentBytes(&uniforms,
                                               length: MemoryLayout<TransferOrbitUniforms>.stride,
                                               index: 0)
        context.renderEncoder.drawPrimitives(type: .lineStrip,
                                             vertexStart: 0,
                                             vertexCount: vertices.count)
    }

    private func circlePoints(center: SIMD3<Float>,
                              radius: Float,
                              sampleCount: Int = 256) -> [SIMD3<Float>] {
        guard radius > 0, sampleCount >= 3 else { return [] }

        return (0...sampleCount).map { index in
            let angle = Float(index) / Float(sampleCount) * 2 * .pi
            return SIMD3<Float>(center.x + radius * cos(angle),
                                center.y + radius * sin(angle),
                                center.z)
        }
    }

    private func makeVertices(points: [SIMD3<Float>]) -> [TransferOrbitVertex] {
        points.enumerated().map { index, point in
            let progress = Float(index) / Float(max(points.count - 1, 1))
            return TransferOrbitVertex(positionAndProgress: SIMD4<Float>(point.x,
                                                                         point.y,
                                                                         point.z,
                                                                         progress))
        }
    }

    private static func makePipelineState(device: MTLDevice,
                                          sampleCount: Int) -> MTLRenderPipelineState {
        let library: MTLLibrary
        do {
            library = try device.makeDefaultLibrary(bundle: .module)
        } catch {
            fatalError("Failed to load Metal shader library from UniverseModule bundle: \(error)")
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.rasterSampleCount = sampleCount
        descriptor.colorAttachments[0].pixelFormat = Self.colorPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].rgbBlendOperation = .add
        descriptor.colorAttachments[0].alphaBlendOperation = .add
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
        descriptor.depthAttachmentPixelFormat = Self.depthPixelFormat
        descriptor.vertexFunction = library.makeFunction(name: "transfer_orbit_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "transfer_orbit_fragment")

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create transfer orbit pipeline state: \(error)")
        }
    }

    private static func makeDepthStencilState(device: MTLDevice) -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .lessEqual
        descriptor.isDepthWriteEnabled = true
        guard let state = device.makeDepthStencilState(descriptor: descriptor) else {
            fatalError("Failed to create transfer orbit depth stencil state")
        }
        return state
    }
}

private struct TransferOrbitVertex {
    var positionAndProgress: SIMD4<Float>
}

private struct RenderContext {
    let renderEncoder: MTLRenderCommandEncoder
    let viewMatrix: float4x4
    let projectionMatrix: float4x4
    let sceneOrigin: SIMD3<Float>
}

private struct TransferOrbitUniforms {
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
    var sceneOriginAndOpacity: SIMD4<Float>
    var color: SIMD4<Float>
    var dash: SIMD4<Float>
}
