#include <metal_stdlib>
using namespace metal;

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
    float4 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float3 worldPos;
};

vertex VertexOut chromosphere_vertex(const VertexIn in [[stage_in]],
                                     constant float4x4 &mvpMatrix [[buffer(1)]],
                                     constant float4x4 &modelMatrix [[buffer(2)]]) {
    constexpr float epsilon = 0.002;
    float4 offsetPos = in.position + float4(in.normal * epsilon, 0.0);
    VertexOut out;
    out.position = mvpMatrix * offsetPos;
    out.worldPos = (modelMatrix * offsetPos).xyz;
    out.normal = normalize((modelMatrix * float4(in.normal, 0.0)).xyz);
    return out;
}

fragment float4 chromosphere_fragment(VertexOut in [[stage_in]],
                                      constant float &time [[buffer(0)]],
                                      constant float &rimIntensity [[buffer(1)]],
                                      constant float &rimFalloff [[buffer(2)]],
                                      constant float &flickerSpeed [[buffer(3)]]) {
    float3 viewDir = normalize(-in.worldPos);
    float mu = saturate(dot(normalize(in.normal), viewDir));
    float rim = pow(max(0.0, 1.0 - mu), rimFalloff);
    if (rim <= 0.001) discard_fragment();

    float flicker = fbm(in.worldPos * 10.0 + float3(0.0, 0.0, time * flickerSpeed));
    flicker = 0.8 + 0.2 * flicker;

    float intensity = rimIntensity * rim * flicker;
    float3 color = float3(1.0, 0.5, 0.1) * intensity;
    return float4(color, 1.0);
}

