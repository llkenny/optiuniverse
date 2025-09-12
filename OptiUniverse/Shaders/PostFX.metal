#include <metal_stdlib>
using namespace metal;

struct PostFXParams {
    float bloomThreshold;
    float bloomRadius;
    float lensDirtOpacity;
};

struct FullscreenOut {
    float4 position [[position]];
    float2 uv;
};

fragment float4 postfx_fragment(FullscreenOut in [[stage_in]],
                                texture2d<float> hdrTexture [[texture(0)]],
                                texture2d<float> lensDirtTexture [[texture(1)]],
                                constant PostFXParams &params [[buffer(0)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    float3 hdr = hdrTexture.sample(s, in.uv).rgb;

    float3 bloom = float3(0.0);
    for (int i = 1; i <= 4; ++i) {
        float lod = params.bloomRadius * float(i);
        bloom += hdrTexture.sample(s, in.uv, level(lod)).rgb;
    }
    bloom /= 4.0;
    bloom = max(bloom - params.bloomThreshold, float3(0.0));

    float dirt = lensDirtTexture.sample(s, in.uv).r;
    bloom *= mix(1.0, dirt, params.lensDirtOpacity);

    float3 color = hdr + bloom;

    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    color = saturate((color * (a * color + b)) / (color * (c * color + d) + e));

    float2 centered = in.uv - 0.5;
    float vignette = smoothstep(0.8, 1.0, length(centered) * 1.4142);
    color *= (1.0 - 0.15 * vignette);

    return float4(color, 1.0);
}
