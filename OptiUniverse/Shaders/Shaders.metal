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
    float3 normal [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float3 normal;
    float3 worldPos;
};

vertex VertexOut vertex_main(
                             const VertexIn in [[stage_in]],
                             constant float4x4 &mvpMatrix [[buffer(1)]],
                             constant float4x4 &modelMatrix [[buffer(2)]]
                             ) {
    VertexOut out;
    out.position = mvpMatrix * in.position;
    out.worldPos = (modelMatrix * in.position).xyz;
    out.normal = normalize((modelMatrix * float4(in.normal, 0.0)).xyz);
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> planetTexture [[texture(0)]],
                              sampler textureSampler [[sampler(0)]]) {
    float4 color = planetTexture.sample(textureSampler, in.texCoord);
    return color;
}

// Specialized fragment shader for the Sun. Produces an animated
// procedural surface and bright corona.
fragment float4 fragment_sun(VertexOut in [[stage_in]],
                             constant float &time [[buffer(0)]],
                             texture2d<float> planetTexture [[texture(0)]],
                             sampler textureSampler [[sampler(0)]]) {
    // Center UV on (0,0)
    float2 uv = in.texCoord * 2.0 - 1.0;
    float r = length(uv);

    // Rotate texture coordinates over time for swirling motion
    float angle = time * 0.1;
    float2 rotUV = float2(uv.x * cos(angle) - uv.y * sin(angle),
                          uv.x * sin(angle) + uv.y * cos(angle));

    // Simple procedural noise based on sine waves
    float noise = sin((rotUV.x + time) * 20.0) * sin((rotUV.y - time) * 20.0);
    noise = noise * 0.5 + 0.5; // Normalize to 0..1

    // Base color mixed with sampled texture to keep some variation
    float3 baseTex = planetTexture.sample(textureSampler, in.texCoord).rgb;
    float3 base = mix(baseTex, float3(1.0, 0.5, 0.0), 0.8);
    float3 surface = base + noise * float3(0.5, 0.3, 0.0);

    // Bright core towards the center
    float core = pow(max(0.0, 1.0 - r), 4.0);
    float3 coreColor = float3(1.0, 0.9, 0.6) * core;

    // Intense glow near the edges for corona effect
    float glow = smoothstep(0.7, 1.0, r);
    float3 glowColor = float3(1.0, 0.6, 0.1) * glow;

    float3 color = surface + coreColor + glowColor;
    return float4(color, 1.0);
}

fragment float4 fragment_main_debug(VertexOut in [[stage_in]]) {
    return float4(in.texCoord.x, in.texCoord.y, 0.0, 1.0);
}

//fragment float4 fragment_main(VertexOut in [[stage_in]]) {
//    return float4(in.texCoord.x, in.texCoord.y, 0.0, 1.0);
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
