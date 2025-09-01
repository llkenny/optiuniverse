//
//  Postprocess.metal
//  OptiUniverse
//
//  Created by max on 01.09.2025.
//

#include <metal_stdlib>
using namespace metal;

struct QuadVSOut { float4 pos [[position]]; float2 uv; };
vertex QuadVSOut vs_fullscreen(uint vid [[vertex_id]]) {
    float2 p = float2((vid << 1) & 2, vid & 2);
    QuadVSOut o;
    o.pos = float4(p * 2.0 - 1.0, 0, 1);
    o.uv  = float2(p.x, 1.0 - p.y);
    return o;
}

struct BloomUniforms {
    float2 texelSize;   // 1/width, 1/height
    float  threshold;   // e.g. 1.0
    float  intensity;   // e.g. 0.8
};

fragment float4 ps_brightpass(QuadVSOut in [[stage_in]],
                              texture2d<float> src [[texture(0)]],
                              constant BloomUniforms& bu [[buffer(0)]])
{
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float3 c = src.sample(s, in.uv).rgb;
    float l = max(max(c.r, c.g), c.b);
    float3 outc = max(c - bu.threshold, 0.0);
    // Optional soft knee
    outc *= smoothstep(0.0, 1.0, l);
    return float4(outc, 1.0);
}

fragment float4 ps_blur_h(QuadVSOut in [[stage_in]],
                          texture2d<float> src [[texture(0)]],
                          constant BloomUniforms& bu [[buffer(0)]])
{
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 o = float2(bu.texelSize.x, 0.0);
    // 9-tap Gaussian-ish
    float w[5] = {0.227027f, 0.1945946f, 0.1216216f, 0.054054f, 0.016216f};
    float3 c = src.sample(s, in.uv).rgb * w[0];
    for (int i=1;i<5;i++){
        c += src.sample(s, in.uv + o * float(i)).rgb * w[i];
        c += src.sample(s, in.uv - o * float(i)).rgb * w[i];
    }
    return float4(c, 1.0);
}

fragment float4 ps_blur_v(QuadVSOut in [[stage_in]],
                          texture2d<float> src [[texture(0)]],
                          constant BloomUniforms& bu [[buffer(0)]])
{
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 o = float2(0.0, bu.texelSize.y);
    float w[5] = {0.227027f, 0.1945946f, 0.1216216f, 0.054054f, 0.016216f};
    float3 c = src.sample(s, in.uv).rgb * w[0];
    for (int i=1;i<5;i++){
        c += src.sample(s, in.uv + o * float(i)).rgb * w[i];
        c += src.sample(s, in.uv - o * float(i)).rgb * w[i];
    }
    return float4(c, 1.0);
}

fragment float4 ps_composite(QuadVSOut in [[stage_in]],
                             texture2d<float> scene   [[texture(0)]],
                             texture2d<float> bloom   [[texture(1)]],
                             constant BloomUniforms& bu [[buffer(0)]])
{
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float3 a = scene.sample(s, in.uv).rgb;
    float3 b = bloom.sample(s, in.uv).rgb * bu.intensity;
    return float4(a + b, 1.0);
}
