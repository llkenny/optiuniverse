#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float4 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPos;
};

vertex VertexOut corona_vertex(const VertexIn in [[stage_in]],
                               constant float4x4 &mvpMatrix [[buffer(1)]],
                               constant float4x4 &modelMatrix [[buffer(2)]]) {
    VertexOut out;
    out.position = mvpMatrix * in.position;
    out.worldPos = (modelMatrix * in.position).xyz;
    return out;
}

struct CoronaParams {
    float3 cameraPos;
    float3 sunPos;
    float  time;
    float  intensity;
    float  noiseScale;
    float  noiseSpeed;
};

fragment float4 corona_sphere_fragment(VertexOut in [[stage_in]],
                                       constant CoronaParams &params [[buffer(0)]],
                                       texture2d<float> coronaGradient [[texture(0)]],
                                       texture2d<float> coronaNoise [[texture(1)]],
                                       sampler sLinear [[sampler(0)]]) {
    float3 dir = normalize(in.worldPos - params.sunPos);
    float3 viewDir = normalize(params.cameraPos - params.sunPos);
    float r = length(cross(dir, viewDir));
    r = clamp(r, 0.0, 1.0);

    float grad = coronaGradient.sample(sLinear, float2(r, 0.5)).r;
    float2 noiseUV = dir.xy * params.noiseScale + params.time * params.noiseSpeed;
    float noise = coronaNoise.sample(sLinear, fract(noiseUV)).r;
    float3 color = float3(1.0, 0.8, 0.3) * (0.8 + 0.2 * noise) * params.intensity;
    return float4(color * grad, grad);
}

