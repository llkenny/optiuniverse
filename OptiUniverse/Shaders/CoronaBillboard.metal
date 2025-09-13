#include <metal_stdlib>
using namespace metal;

// Hash and FBM helpers for flow noise
static float hash(float3 p) {
    return fract(sin(dot(p, float3(12.9898,78.233,37.719))) * 43758.5453);
}

static float fbm(float3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 3; ++i) {
        value += amplitude * hash(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

struct VertexIn {
    float2 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
    float  layer;
    float3 worldPos;
};

vertex VertexOut corona_vertex(const VertexIn in                 [[stage_in]],
                               constant float4x4 &mvpMatrix       [[buffer(1)]],
                               constant float4x4 &modelMatrix     [[buffer(2)]],
                               constant float    &coronaScale     [[buffer(3)]],
                               uint instanceId                     [[instance_id]]) {
    VertexOut out;
    float layer = float(instanceId);
    float scale = coronaScale * (1.0 + layer * 0.2);
    float3 pos = float3(in.position * scale, 0.0);
    float4 world = modelMatrix * float4(pos, 1.0);
    out.position = mvpMatrix * float4(pos, 1.0);
    out.worldPos = world.xyz;
    out.uv = in.position * 0.5 + 0.5;
    out.layer = layer;
    return out;
}

fragment float4 corona_fragment(VertexOut in              [[stage_in]],
                                constant float &time      [[buffer(0)]],
                                constant float &coronaIntensity [[buffer(1)]]) {
    float2 uv = in.uv * 2.0 - 1.0;
    float3 p = float3(uv * (in.layer + 1.0), time * 0.1);
    float distortion = fbm(p);
    uv += distortion * 0.1;
    float r = length(uv);
    float falloff = exp(-r * (in.layer + 1.0));
    float3 color = float3(1.0, 0.8, 0.3) * coronaIntensity * falloff;
    return float4(color, 1.0); // Additive blending
}

