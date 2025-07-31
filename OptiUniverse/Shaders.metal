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
    float4 position [[attribute(0)]];
//    float3 color [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
//    float4 color;
};

vertex VertexOut vertex_main(
                             const VertexIn in [[stage_in]],
                             constant float4x4 &mvpMatrix [[buffer(1)]]
                             ) {
    VertexOut out;
    out.position = mvpMatrix * in.position;
    return out;
////    out.position = mvpMatrix * float4(in.position, 1.0);
//    out.position = float4(in.position, 1.0);
////    out.color = float4(in.color, 1.0);
////    out.color = float4(0, 1, 0, 1);
//    return out;
}

//fragment float4 fragment_main(VertexOut in [[stage_in]]) {
//    return in.color;
//}

fragment float4 basic_fragment() {
    return float4(0, 0, 1, 1);
}

// Axes Shaders in your .metal file
struct AxesVertexOut {
    float4 position [[position]];
    float3 color;
};

vertex AxesVertexOut axes_vertex(
                                 const device packed_float3 *vertices [[buffer(0)]],
                                 constant float4x4 &mvpMatrix [[buffer(1)]],
                                 uint vid [[vertex_id]]
                                 ) {
    AxesVertexOut out;
    float3 position = vertices[vid * 2];     // Position is first 3 floats
    out.color = vertices[vid * 2 + 1];       // Color is next 3 floats
    out.position = mvpMatrix * float4(position, 1.0);
    return out;
}

fragment float4 axes_fragment(AxesVertexOut in [[stage_in]]) {
    return float4(in.color, 1.0);
}
