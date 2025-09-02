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

// ---------------------------------------------------------------
// Noise helpers for procedural solar effects
// ---------------------------------------------------------------

/// Hash function returning a pseudo-random value in [0,1]
inline float hash(float3 p) {
    p = fract(p * 0.3183099 + float3(0.1, 0.1, 0.1));
    p *= 17.0;
    return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

/// Smooth value noise based on hashing the corners of the cell
inline float noise(float3 p) {
    float3 i = floor(p);
    float3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f); // Smooth interpolation curve

    float n000 = hash(i + float3(0.0, 0.0, 0.0));
    float n100 = hash(i + float3(1.0, 0.0, 0.0));
    float n010 = hash(i + float3(0.0, 1.0, 0.0));
    float n110 = hash(i + float3(1.0, 1.0, 0.0));
    float n001 = hash(i + float3(0.0, 0.0, 1.0));
    float n101 = hash(i + float3(1.0, 0.0, 1.0));
    float n011 = hash(i + float3(0.0, 1.0, 1.0));
    float n111 = hash(i + float3(1.0, 1.0, 1.0));

    float n00 = mix(n000, n100, f.x);
    float n10 = mix(n010, n110, f.x);
    float n01 = mix(n001, n101, f.x);
    float n11 = mix(n011, n111, f.x);
    float n0 = mix(n00, n10, f.y);
    float n1 = mix(n01, n11, f.y);
    return mix(n0, n1, f.z);
}

/// Fractal Brownian Motion for turbulent solar surface
inline float fbm(float3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 5; ++i) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

// Specialized fragment shader for the Sun. Produces an animated
// procedural surface, a dynamic corona and prominences with high fidelity.
fragment float4 fragment_sun(VertexOut in [[stage_in]],
                             constant float &time [[buffer(0)]],
                             texture2d<float> planetTexture [[texture(0)]],
                             sampler textureSampler [[sampler(0)]]) {
    // Center UV on (0,0)
    float2 uv = in.texCoord * 2.0 - 1.0;
    float r = length(uv);
    float ang = atan2(uv.y, uv.x);

    // Gentle rotation for subtle motion
    float rotation = time * 0.02;
    float2 rotUV = float2(uv.x * cos(rotation) - uv.y * sin(rotation),
                          uv.x * sin(rotation) + uv.y * cos(rotation));

    // Turbulent surface using fractal noise
    float granulation = fbm(float3(rotUV * 5.0, time * 0.1));

    // Base color mostly procedural to mask texture rectangles
    float3 baseTex = planetTexture.sample(textureSampler, in.texCoord).rgb;
    float3 base = mix(baseTex, float3(1.0, 0.5, 0.0), 0.9);
    float3 surface = base + granulation * float3(0.8, 0.5, 0.2);

    // Limb darkening for a spherical appearance
    float limb = smoothstep(0.8, 1.0, r);
    surface *= 1.0 - limb * 0.5;

    // Bright core towards the center
    float core = pow(max(0.0, 1.0 - r), 5.0);
    float3 coreColor = float3(1.0, 0.95, 0.8) * core;

    // Corona with radial falloff and turbulence
    float coronaNoise = fbm(float3(uv * 8.0, time * 0.2));
    float corona = smoothstep(0.7, 1.0, r) * coronaNoise;
    float3 coronaColor = float3(1.0, 0.8, 0.3) * pow(corona, 2.0);

    // Animated prominences emerging from the surface
    float promSeed = sin(ang * 12.0 + time * 0.7) + fbm(float3(ang * 2.0, time, 0.0));
    float prominence = pow(max(0.0, promSeed), 4.0) * smoothstep(1.0, 1.3, r);
    float3 prominenceColor = float3(1.0, 0.5, 0.2) * prominence;

    float3 color = surface + coreColor + coronaColor + prominenceColor;
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
