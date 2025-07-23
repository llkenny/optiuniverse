//
//  VertexIn.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//


// Shaders.metal
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vertex_main(
                             const VertexIn in [[stage_in]],
                             constant float4x4 &mvpMatrix [[buffer(1)]]
                             ) {
    VertexOut out;
    out.position = mvpMatrix * float4(in.position, 1.0);
    out.color = float4(in.color, 1.0);
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    return in.color;
}
