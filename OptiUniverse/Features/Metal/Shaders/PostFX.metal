#include <metal_stdlib>
using namespace metal;

struct PostFXParams {
    float bloomThreshold;
    float bloomRadius;
    float lensDirtOpacity;
    uint style;
    float dreamyIntensity;
    float softFocusRadius;
    float hazeStrength;
    float saturationBoost;
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
    float2 texelSize = 1.0 / float2(hdrTexture.get_width(), hdrTexture.get_height());

    float3 bloom = float3(0.0);
    for (int i = 1; i <= 4; ++i) {
        float lod = params.bloomRadius * float(i);
        bloom += hdrTexture.sample(s, in.uv, level(lod)).rgb;
    }
    bloom /= 4.0;
    bloom = max(bloom - params.bloomThreshold, float3(0.0));

    float3 softFocus = hdr;
    if (params.style == 1 && params.dreamyIntensity > 0.0) {
        float2 blurOffset = texelSize * params.softFocusRadius;
        softFocus += hdrTexture.sample(s, in.uv + float2( blurOffset.x, 0.0)).rgb;
        softFocus += hdrTexture.sample(s, in.uv + float2(-blurOffset.x, 0.0)).rgb;
        softFocus += hdrTexture.sample(s, in.uv + float2(0.0,  blurOffset.y)).rgb;
        softFocus += hdrTexture.sample(s, in.uv + float2(0.0, -blurOffset.y)).rgb;
        softFocus += hdrTexture.sample(s, in.uv + blurOffset).rgb;
        softFocus += hdrTexture.sample(s, in.uv - blurOffset).rgb;
        softFocus += hdrTexture.sample(s, in.uv + float2( blurOffset.x, -blurOffset.y)).rgb;
        softFocus += hdrTexture.sample(s, in.uv + float2(-blurOffset.x,  blurOffset.y)).rgb;
        softFocus /= 9.0;
    }

    float dirt = lensDirtTexture.sample(s, in.uv).r;
    bloom *= mix(1.0, dirt, params.lensDirtOpacity);

    float3 color = hdr + bloom;

    if (params.style == 1 && params.dreamyIntensity > 0.0) {
        float dreamyAmount = saturate(params.dreamyIntensity);
        float softLuma = dot(softFocus, float3(0.2126, 0.7152, 0.0722));
        float hazeMask = smoothstep(0.12, 1.2, softLuma);
        float3 warmHaze = float3(1.0, 0.96, 0.9) * softLuma * params.hazeStrength;

        color = mix(color, softFocus + bloom * 1.35, 0.45 * dreamyAmount);
        color += warmHaze * dreamyAmount * hazeMask;
        color = mix(color, sqrt(max(color, 0.0)), 0.18 * dreamyAmount);
    }

    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    color = saturate((color * (a * color + b)) / (color * (c * color + d) + e));

    if (params.style == 1 && params.dreamyIntensity > 0.0) {
        float dreamyAmount = saturate(params.dreamyIntensity);
        float luminance = dot(color, float3(0.2126, 0.7152, 0.0722));
        float3 highlightTint = float3(1.02, 0.99, 0.95);
        float3 shadowTint = float3(0.97, 0.99, 1.03);
        color *= mix(shadowTint, highlightTint, saturate(luminance * 1.25));
        float3 gray = float3(dot(color, float3(0.299, 0.587, 0.114)));
        color = mix(gray, color, params.saturationBoost);
        color = mix(color, smoothstep(0.0, 1.0, color), 0.12 * dreamyAmount);
    }

    float2 centered = in.uv - 0.5;
    float vignette = smoothstep(0.8, 1.0, length(centered) * 1.4142);
    float vignetteStrength = params.style == 1 ? 0.08 : 0.15;
    color *= (1.0 - vignetteStrength * vignette);

    return float4(color, 1.0);
}
