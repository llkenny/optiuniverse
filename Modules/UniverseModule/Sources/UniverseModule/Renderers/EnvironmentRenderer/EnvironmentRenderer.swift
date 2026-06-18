//
//  EnvironmentRenderer.swift
//  UniverseModule
//
//  Created by Codex on 07.06.2026.
//

import MetalKit
import simd

/// Draws the equirectangular deep-space background as the first HDR pass.
///
/// The renderer strips camera translation from the view matrix so the Milky Way
/// behaves like an infinite environment while still rotating with the camera.
final class EnvironmentRenderer {
    private static let colorPixelFormat: MTLPixelFormat = .rgba16Float
    private static let depthPixelFormat: MTLPixelFormat = .depth32Float

    private let pipelineState: MTLRenderPipelineState
    private let depthStencilState: MTLDepthStencilState
    private let environmentTexture: MTLTexture?

    init(device: MTLDevice, sampleCount: Int) {
        environmentTexture = Self.makeEnvironmentTexture(device: device)
        pipelineState = Self.makePipelineState(device: device, sampleCount: sampleCount)
        depthStencilState = Self.makeDepthStencilState(device: device)
    }

    func render(renderEncoder: MTLRenderCommandEncoder,
                viewMatrix: float4x4,
                projectionMatrix: float4x4) {
        guard let environmentTexture else { return }

        var viewRotationMatrix = viewMatrix
        viewRotationMatrix.columns.3 = SIMD4<Float>(0, 0, 0, 1)

        var uniforms = EnvironmentUniforms(
            inverseProjectionMatrix: simd_inverse(projectionMatrix),
            inverseViewRotationMatrix: simd_inverse(viewRotationMatrix),
            exposure: 0.3,
            saturation: 0.7,
            padding: SIMD2<Float>(repeating: 0)
        )

        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthStencilState)
        renderEncoder.setFragmentTexture(environmentTexture, index: 0)
        renderEncoder.setFragmentBytes(&uniforms,
                                       length: MemoryLayout<EnvironmentUniforms>.stride,
                                       index: 0)
        renderEncoder.drawPrimitives(type: .triangle,
                                     vertexStart: 0,
                                     vertexCount: 3)
    }

    private static func makeEnvironmentTexture(device: MTLDevice) -> MTLTexture? {
        guard let url = UniverseModuleAssets.milkyWayEnvironmentURL() else {
            return nil
        }

        let loader = MTKTextureLoader(device: device)
        return try? loader.newTexture(
            URL: url,
            options: [
                .SRGB: true,
                .generateMipmaps: true,
                .origin: MTKTextureLoader.Origin.topLeft.rawValue
            ]
        )
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
        descriptor.depthAttachmentPixelFormat = Self.depthPixelFormat
        descriptor.vertexFunction = library.makeFunction(name: "fullscreen_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "environment_fragment")

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create environment pipeline state: \(error)")
        }
    }

    private static func makeDepthStencilState(device: MTLDevice) -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .always
        descriptor.isDepthWriteEnabled = false
        guard let state = device.makeDepthStencilState(descriptor: descriptor) else {
            fatalError("Failed to create environment depth stencil state")
        }
        return state
    }
}

private struct EnvironmentUniforms {
    var inverseProjectionMatrix: float4x4
    var inverseViewRotationMatrix: float4x4
    var exposure: Float
    var saturation: Float
    var padding: SIMD2<Float>
}
