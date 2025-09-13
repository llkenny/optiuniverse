#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float3 normal;
    float3 worldPos;
};

struct CoronaUniforms {
    float3 cameraPos;
    float3 sunPos;
    float outerRadius;
    float time;
    float intensity;
    float noiseScale;
    float flickerSpeed;
};

fragment float4 corona_sphere_fragment(VertexOut in [[stage_in]],
                                       constant CoronaUniforms &uni [[buffer(0)]],
                                       texture2d<float> coronaGradient [[texture(0)]],
                                       texture2d<float> coronaNoise [[texture(1)]],
                                       sampler sLinear [[sampler(0)]]) {
    float3 viewDir = normalize(uni.cameraPos - uni.sunPos);
    float3 toPoint = in.worldPos - uni.sunPos;
    float3 radial = toPoint - dot(toPoint, viewDir) * viewDir;
    float r = length(radial) / uni.outerRadius;

    float grad = coronaGradient.sample(sLinear, float2(r, 0.5)).r;
    float2 noiseUV = radial.xy / uni.outerRadius * uni.noiseScale + uni.time * uni.flickerSpeed;
    float flicker = coronaNoise.sample(sLinear, noiseUV).r;
    float intensity = uni.intensity * (0.8 + 0.2 * flicker);
    float3 color = float3(1.0, 0.8, 0.3) * intensity;
    return float4(color * grad, grad);
}

