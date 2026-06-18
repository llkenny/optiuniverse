//
//  RouteRenderer.swift
//  MetalModule
//
//  Created by Codex on 11.05.2026.
//

import Metal
import simd

protocol RouteRendering {
    func render(configuration: RouteRenderConfiguration)
}

struct NavigationRouteRenderState {
    let route: NavigationRoute?
    let progress: Float
    let elapsedTime: TimeInterval
}

struct RouteRenderConfiguration {
    let state: NavigationRouteRenderState
    let renderEncoder: MTLRenderCommandEncoder
    let viewMatrix: float4x4
    let projectionMatrix: float4x4
    let sceneOrigin: SIMD3<Float>
    let viewportSize: CGSize
}

final class RouteRenderer: RouteRendering {
    private static let colorPixelFormat: MTLPixelFormat = .rgba16Float
    private static let depthPixelFormat: MTLPixelFormat = .depth32Float

    private let device: MTLDevice
    private let linePipelineState: MTLRenderPipelineState
    private let pipelineState: MTLRenderPipelineState
    private let depthStencilState: MTLDepthStencilState
    private let sceneOwnershipControls: MetalSceneOwnershipControls

    init(device: MTLDevice,
         sampleCount: Int,
         sceneOwnershipControls: MetalSceneOwnershipControls) {
        self.device = device
        self.sceneOwnershipControls = sceneOwnershipControls
        linePipelineState = Self.makeLinePipelineState(device: device,
                                                       sampleCount: sampleCount)
        pipelineState = Self.makePipelineState(device: device,
                                               sampleCount: sampleCount)
        depthStencilState = Self.makeDepthStencilState(device: device)
    }

    func render(configuration: RouteRenderConfiguration) {
        guard let route = configuration.state.route else {
            return
        }

        if sceneOwnershipControls.renders(.navigationRoute) {
            renderRoutePath(route: route,
                            configuration: configuration)
        }

        guard sceneOwnershipControls.renders(.navigationMarker),
              let markerPosition = route.point(at: configuration.state.progress) else {
            return
        }

        renderNavigationMarker(at: markerPosition,
                               configuration: configuration)
    }

    private func renderNavigationMarker(at markerPosition: SIMD3<Float>,
                                        configuration: RouteRenderConfiguration) {
        var vertex = RouteMarkerVertex(positionAndProgress: SIMD4<Float>(markerPosition.x,
                                                                         markerPosition.y,
                                                                         markerPosition.z,
                                                                         configuration.state.progress))
        var uniforms = RouteMarkerUniforms(
            viewMatrix: configuration.viewMatrix,
            projectionMatrix: configuration.projectionMatrix,
            sceneOriginAndOpacity: SIMD4<Float>(configuration.sceneOrigin.x,
                                                configuration.sceneOrigin.y,
                                                configuration.sceneOrigin.z,
                                                1.0),
            color: SIMD4<Float>(0.25, 0.95, 1.0, 1.0),
            params: SIMD4<Float>(Float(configuration.state.elapsedTime),
                                 30,
                                 0,
                                 0)
        )

        configuration.renderEncoder.setRenderPipelineState(pipelineState)
        configuration.renderEncoder.setDepthStencilState(depthStencilState)
        configuration.renderEncoder.setVertexBytes(&vertex,
                                                   length: MemoryLayout<RouteMarkerVertex>.stride,
                                                   index: 0)
        configuration.renderEncoder.setVertexBytes(&uniforms,
                                                   length: MemoryLayout<RouteMarkerUniforms>.stride,
                                                   index: 1)
        configuration.renderEncoder.setFragmentBytes(&uniforms,
                                                     length: MemoryLayout<RouteMarkerUniforms>.stride,
                                                     index: 0)
        configuration.renderEncoder.drawPrimitives(type: .point,
                                                   vertexStart: 0,
                                                   vertexCount: 1)
    }

    private func renderRoutePath(route: NavigationRoute,
                                 configuration: RouteRenderConfiguration) {
        guard route.points.count >= 2 else { return }

        let vertices = route.points.enumerated().map { index, point in
            let progress = Float(index) / Float(max(route.points.count - 1, 1))
            return RouteLineVertex(positionAndProgress: SIMD4<Float>(point.x,
                                                                     point.y,
                                                                     point.z,
                                                                     progress))
        }
        guard let vertexBuffer = device.makeBuffer(bytes: vertices,
                                                   length: MemoryLayout<RouteLineVertex>.stride * vertices.count,
                                                   options: .storageModeShared) else {
            return
        }

        var uniforms = RouteLineUniforms(
            viewMatrix: configuration.viewMatrix,
            projectionMatrix: configuration.projectionMatrix,
            sceneOriginAndOpacity: SIMD4<Float>(configuration.sceneOrigin.x,
                                                configuration.sceneOrigin.y,
                                                configuration.sceneOrigin.z,
                                                0.95),
            color: SIMD4<Float>(0.2, 0.82, 1.0, 1.0),
            dash: SIMD4<Float>(0, 1, 0, 0)
        )

        configuration.renderEncoder.setRenderPipelineState(linePipelineState)
        configuration.renderEncoder.setDepthStencilState(depthStencilState)
        configuration.renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        configuration.renderEncoder.setVertexBytes(&uniforms,
                                                   length: MemoryLayout<RouteLineUniforms>.stride,
                                                   index: 1)
        configuration.renderEncoder.setFragmentBytes(&uniforms,
                                                     length: MemoryLayout<RouteLineUniforms>.stride,
                                                     index: 0)
        configuration.renderEncoder.drawPrimitives(type: .lineStrip,
                                                   vertexStart: 0,
                                                   vertexCount: vertices.count)
    }

    private static func makeLinePipelineState(device: MTLDevice,
                                              sampleCount: Int) -> MTLRenderPipelineState {
        let library: MTLLibrary
        do {
            library = try device.makeDefaultLibrary(bundle: .module)
        } catch {
            fatalError("Failed to load Metal shader library from MetalModule bundle: \(error)")
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
            fatalError("Failed to create route line pipeline state: \(error)")
        }
    }

    private static func makePipelineState(device: MTLDevice,
                                          sampleCount: Int) -> MTLRenderPipelineState {
        let library: MTLLibrary
        do {
            library = try device.makeDefaultLibrary(bundle: .module)
        } catch {
            fatalError("Failed to load Metal shader library from MetalModule bundle: \(error)")
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
        descriptor.vertexFunction = library.makeFunction(name: "route_marker_vertex")
        descriptor.fragmentFunction = library.makeFunction(name: "route_marker_fragment")

        do {
            return try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            fatalError("Failed to create route marker pipeline state: \(error)")
        }
    }

    private static func makeDepthStencilState(device: MTLDevice) -> MTLDepthStencilState {
        let descriptor = MTLDepthStencilDescriptor()
        descriptor.depthCompareFunction = .lessEqual
        descriptor.isDepthWriteEnabled = false
        guard let state = device.makeDepthStencilState(descriptor: descriptor) else {
            fatalError("Failed to create route marker depth stencil state")
        }
        return state
    }
}

private struct RouteLineVertex {
    var positionAndProgress: SIMD4<Float>
}

private struct RouteLineUniforms {
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
    var sceneOriginAndOpacity: SIMD4<Float>
    var color: SIMD4<Float>
    var dash: SIMD4<Float>
}

private struct RouteMarkerVertex {
    var positionAndProgress: SIMD4<Float>
}

private struct RouteMarkerUniforms {
    var viewMatrix: float4x4
    var projectionMatrix: float4x4
    var sceneOriginAndOpacity: SIMD4<Float>
    var color: SIMD4<Float>
    var params: SIMD4<Float>
}
