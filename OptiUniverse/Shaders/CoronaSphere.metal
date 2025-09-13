#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float2 uv       [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldPos;
    float3 normal;
};

vertex VertexOut corona_sphere_vertex(const VertexIn in               [[stage_in]],
                                      constant float4x4 &mvpMatrix    [[buffer(1)]],
                                      constant float4x4 &modelMatrix  [[buffer(2)]]) {
    VertexOut out;
    float4 world = modelMatrix * float4(in.position, 1.0);
    out.position = mvpMatrix * float4(in.position, 1.0);
    out.worldPos = world.xyz;
    out.normal = normalize((modelMatrix * float4(in.normal, 0.0)).xyz);
    return out;
}

struct CoronaParams {
    float3 cameraPos;
    float  time;
    float  intensity;
    float  scale;
    float  flickerSpeed;
};

fragment float4 corona_sphere_fragment(VertexOut in                    [[stage_in]],
                                       constant CoronaParams &params  [[buffer(0)]],
                                       texture2d<float> coronaGradient [[texture(0)]],
                                       texture2d<float> coronaNoise    [[texture(1)]],
                                       sampler sLinear                 [[sampler(0)]]) {
    float3 viewDir = normalize(params.cameraPos - in.worldPos);
    float3 normal = normalize(in.normal);
    float ndv = dot(normal, viewDir);
    float r = sqrt(saturate(1.0 - ndv * ndv));
    float grad = coronaGradient.sample(sLinear, float2(r, 0.5)).r;

    float2 uvNoise = float2(atan2(normal.z, normal.x) / (2.0f * M_PI_F) + 0.5,
                            normal.y * 0.5 + 0.5);
    uvNoise = uvNoise * params.scale + params.time * params.flickerSpeed;
    float flicker = coronaNoise.sample(sLinear, uvNoise).r;

    float3 baseColor = float3(1.0, 0.8, 0.3);
    float3 color = baseColor * params.intensity * (0.8 + 0.2 * flicker);
    return float4(color * grad, grad);
}

