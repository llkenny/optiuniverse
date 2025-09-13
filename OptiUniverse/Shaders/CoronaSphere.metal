#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float4 clipPosition;
};

vertex VertexOut corona_sphere_vertex(VertexIn in [[stage_in]],
                                      constant float4x4 &mvp [[buffer(1)]]) {
    VertexOut out;
    float4 pos = float4(in.position, 1.0);
    out.position = mvp * pos;
    out.clipPosition = out.position;
    return out;
}

struct CoronaParams {
    float time;
    float coronaIntensity;
    float coronaScale;
    float flickerSpeed;
};

fragment float4 corona_sphere_fragment(VertexOut in [[stage_in]],
                                       constant CoronaParams &params [[buffer(0)]],
                                       texture2d<float> coronaGradient [[texture(0)]],
                                       texture2d<float> coronaNoise [[texture(1)]],
                                       sampler s [[sampler(0)]]) {
    float2 ndc = in.clipPosition.xy / in.clipPosition.w;
    float r = length(ndc);
    float grad = coronaGradient.sample(s, float2(r, 0.5)).r;
    float noise = coronaNoise.sample(s, ndc * params.coronaScale + params.time * params.flickerSpeed).r;
    float value = grad * (0.8 + 0.2 * noise) * params.coronaIntensity;
    float3 color = float3(1.0, 0.8, 0.3) * value;
    return float4(color, value);
}

