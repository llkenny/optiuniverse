//
//  VertexIn.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//


// Shaders.metal
#include <metal_stdlib>
using namespace metal;

// Simple hash-based noise for FBM
float hash(float3 p) {
    return fract(sin(dot(p, float3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// Low-iteration FBM returning a 2D warp vector to keep performance high
float2 fbm(float3 p) {
    float2 value = float2(0.0);
    float amplitude = 0.5;
    for (int i = 0; i < 3; ++i) {
        value += amplitude * float2(hash(p), hash(p + 1.0));
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

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
                             constant float &delta [[buffer(1)]],
                             constant float &exposure [[buffer(2)]],
                             texture2d<float> planetTexture [[texture(0)]],
                             texture2d<float> coronaGradient [[texture(1)]],
                             texture2d<float> coronaNoise [[texture(2)]],
                             sampler textureSampler [[sampler(0)]]) {
    // Center UV on (0,0)
    float2 uv = in.texCoord * 2.0 - 1.0;
    float r = length(uv);

    // Rotate texture coordinates over time for swirling motion
    float angle = time * 0.1 * delta;
    float2 rotUV = float2(uv.x * cos(angle) - uv.y * sin(angle),
                          uv.x * sin(angle) + uv.y * cos(angle));

    // Warp UVs using secondary FBM for more turbulent motion
    float2 warp = fbm(float3(rotUV * 10.0, time * 0.3 * delta));
    rotUV += warp * 0.02;

    // Simple procedural noise modulated by provided noise texture
    float noise = sin((rotUV.x + time) * 20.0 * delta) * sin((rotUV.y - time) * 20.0 * delta);
    noise = noise * 0.5 + 0.5; // Normalize to 0..1
    float noiseTex = coronaNoise.sample(textureSampler, rotUV * 4.0).r;
    noise *= noiseTex;

    // Base color mixed with sampled texture to keep some variation
    float3 base = planetTexture.sample(textureSampler, in.texCoord).rgb;
    float3 surface = base + noise * float3(1.0, 0.6, 0.0);

    // Bright core towards the center
    float core = pow(max(0.0, 1.0 - r), 4.0);
      float3 coreColor = float3(30.0, 15.0, 5.0) * core;

    // Multi-layer corona with height-based falloff and gradient colouring
    float height = max(0.0, r - 1.0);
    float density = exp(-height * 8.0);
    float3 coronaColor = coronaGradient.sample(textureSampler, float2(min(r, 1.0), 0.5)).rgb;
    float3 corona = float3(0.0);
    const float freqs[3] = {1.0, 2.0, 4.0};
    for (int i = 0; i < 3; ++i) {
        float f = freqs[i];
        float layer = sin((rotUV.x + time) * 20.0 * f * delta) * sin((rotUV.y - time) * 20.0 * f * delta);
        layer = layer * 0.5 + 0.5;
        corona += coronaColor * (1.0 / (float(i) + 1.0)) * layer;
    }
    corona *= density * noiseTex;

    float3 color = (surface + coreColor + corona) * exposure;
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

    struct FullscreenOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex FullscreenOut fullscreen_vertex(uint vid [[vertex_id]]) {
        float2 pos[3] = {
            float2(-1.0, -1.0),
            float2( 3.0, -1.0),
            float2(-1.0,  3.0)
        };
        FullscreenOut out;
        out.position = float4(pos[vid], 0.0, 1.0);
        out.uv = pos[vid] * 0.5 + 0.5;
        return out;
    }

    fragment float4 tonemap_fragment(FullscreenOut in [[stage_in]],
                                     texture2d<float> hdrTexture [[texture(0)]]) {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        float3 hdr = hdrTexture.sample(s, in.uv).rgb;
        float3 mapped = hdr / (hdr + 1.0);
        return float4(mapped, 1.0);
    }
