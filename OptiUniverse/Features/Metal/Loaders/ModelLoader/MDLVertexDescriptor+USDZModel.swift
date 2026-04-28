//
//  MDLVertexDescriptor+USDZModel.swift
//  OptiUniverse
//
//  Created by max on 27.03.2026.
//

import ModelIO

extension MDLVertexDescriptor {

    nonisolated static func makeUSDZVertexDescriptor() -> MDLVertexDescriptor {
        let descriptor = MDLVertexDescriptor()

        descriptor.attributes[0] = MDLVertexAttribute(
            name: MDLVertexAttributePosition,
            format: .float3,
            offset: 0,
            bufferIndex: 0
        )

        descriptor.attributes[1] = MDLVertexAttribute(
            name: MDLVertexAttributeNormal,
            format: .float3,
            offset: 0,
            bufferIndex: 1
        )

        descriptor.attributes[2] = MDLVertexAttribute(
            name: MDLVertexAttributeTextureCoordinate,
            format: .float2,
            offset: 0,
            bufferIndex: 2
        )

        descriptor.attributes[3] = MDLVertexAttribute(
            name: MDLVertexAttributeTangent,
            format: .float4,
            offset: 0,
            bufferIndex: 3
        )

        descriptor.layouts[0] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.stride)
        descriptor.layouts[1] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD3<Float>>.stride)
        descriptor.layouts[2] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD2<Float>>.stride)
        descriptor.layouts[3] = MDLVertexBufferLayout(stride: MemoryLayout<SIMD4<Float>>.stride)

        return descriptor
    }
}
