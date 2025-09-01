//
//  SunShaders.metal
//  OptiUniverse
//
//  Created by max on 01.09.2025.
//


#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float2 uv       [[attribute(2)]];
};

struct VSOut {
    float4 position [[position]];
    float3 worldPos;
    float3 normal;
    float2 uv;
};

struct SunUniforms {
    float4x4 mvp;
    float    time;
    float    radius;
    float    granulationScale; // e.g. 32–64
    float    flow;             // animation speed, e.g. 0.06
    float    limbU;            // limb darkening coeff, ~0.6
    float    brightness;       // base emissive
    float    coronaStrength;   // 0.0–2.0
};

float hash31(float3 p){
    // Simple, fast hash
    p  = fract(p * 0.1031);
    p += dot(p, p.yzx + 33.33);
    return fract((p.x + p.y) * p.z);
}

float rand3(float3 p) {
    // Fast lattice random
    return fract(sin(dot(p, float3(127.1, 311.7, 74.7))) * 43758.5453);
}

float3 fade(float3 f) { return f*f*f*(f*(f*6.0 - 15.0) + 10.0); } // Perlin fade

float noise3(float3 p) {
    float3 i = floor(p);
    float3 f = fract(p);
    float3 u = fade(f);
    
    float n000 = rand3(i + float3(0,0,0));
    float n100 = rand3(i + float3(1,0,0));
    float n010 = rand3(i + float3(0,1,0));
    float n110 = rand3(i + float3(1,1,0));
    float n001 = rand3(i + float3(0,0,1));
    float n101 = rand3(i + float3(1,0,1));
    float n011 = rand3(i + float3(0,1,1));
    float n111 = rand3(i + float3(1,1,1));
    
    float nx00 = mix(n000, n100, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx11 = mix(n011, n111, u.x);
    
    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);
    
    return mix(nxy0, nxy1, u.z); // 0..1
}

float fbm(float3 p) {
    float amp = 0.5;
    float f = 0.0;
    for (int i=0; i<6; ++i) {
        f += amp * noise3(p);
        p *= 2.03;
        amp *= 0.5;
    }
    return f; // ~0..1
}


// ACES-ish tonemap for nicer bloom thresholding
float3 tonemapACES(float3 x) {
    const float a=2.51, b=0.03, c=2.43, d=0.59, e=0.14;
    return saturate((x*(a*x+b))/(x*(c*x+d)+e));
}

// Simple blackbody-inspired color ramp near ~5800K
float3 sunColor(float t) {
    // t in [0..1] where 0.5 ≈ 5800K look; shift hue slightly with t
    // Base warm yellow/orange ramp
    float3 c1 = float3(1.0, 0.78, 0.35);
    float3 c2 = float3(1.0, 0.90, 0.65);
    return mix(c1, c2, t);
}

vertex VSOut vertex_sun(VertexIn in                 [[stage_in]],
                        constant SunUniforms& uni   [[buffer(1)]])
{
    VSOut o;
    float4 wp = float4(in.position * uni.radius, 1.0);
    o.worldPos = wp.xyz;
    o.normal   = normalize(in.normal);
    o.uv       = in.uv;
    o.position = uni.mvp * wp;
    return o;
}

fragment float4 fragment_sun(VSOut in [[stage_in]],
                             constant SunUniforms& uni [[buffer(1)]])
{
    float3 N = normalize(in.normal);
    float mu = saturate(abs(N.z));
    float limb = 1.0 - uni.limbU * (1.0 - mu);
    
    // Procedural granulation
    float3 p = N * uni.granulationScale + float3(0,0, uni.time * uni.flow);
    float g = fbm(p); // 0..1
    // Push contrast so cells are obvious without blooming to white
    float cells = smoothstep(0.35, 0.75, g);
    
    // Base color (warm)
    float3 base = sunColor(0.58); // a bit warmer than before
    
    // Lower brightness a lot (previous 9.0 was clipping); tweak at runtime if needed
    float exposure = max(uni.brightness, 0.001); // pass ~2.2 from CPU first
    float3 emissive = base * exposure * limb * (0.9 + 0.6*cells);
    
    // Mild center dim so the disk isn't paper-white even at high exposure
    emissive *= (0.98 + 0.02 * mu);
    
    float3 color = tonemapACES(emissive);
    return float4(color, 1.0);
}


// Render on a slightly larger sphere with additive blending
fragment float4 fragment_corona(VSOut in [[stage_in]],
                                constant SunUniforms& uni [[buffer(1)]])
{
    float3 N = normalize(in.normal);
    float mu = saturate(abs(N.z));
    float edge = pow(1.0 - mu, 2.0); // stronger at limb

    float3 p = N * 8.0 + float3(0,0, uni.time * uni.flow * 0.5);
    float swirl = fbm(p) * fbm(p*1.9);
    float flare = edge * (0.6 + 0.8*swirl);

    float3 coronaCol = sunColor(0.6) * (uni.coronaStrength * flare);
    return float4(coronaCol, flare); // alpha will be used by additive blend
}
