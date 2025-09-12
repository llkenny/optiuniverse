#include <metal_stdlib>
using namespace metal;

// Simple hash and FBM helpers
static float hash(float3 p) {
    return fract(sin(dot(p, float3(12.9898,78.233,37.719))) * 43758.5453);
}

static float fbm(float3 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; ++i) {
        value += amplitude * hash(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

static float2 fbm2(float3 p) {
    return float2(fbm(p), fbm(p + 31.416));
}

struct VertexIn {
    float4 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
    float3 normal;
    float3 worldPos;
};

vertex VertexOut photosphere_vertex(
                                    const VertexIn in [[stage_in]],
                                    constant float4x4 &mvpMatrix [[buffer(1)]],
                                    constant float4x4 &modelMatrix [[buffer(2)]]) {
    VertexOut out;
    out.position = mvpMatrix * in.position;
    out.worldPos = (modelMatrix * in.position).xyz;
    out.normal = normalize((modelMatrix * float4(in.normal, 0.0)).xyz);
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 photosphere_fragment(VertexOut in [[stage_in]],
                                     constant float &time [[buffer(0)]],
                                     constant float &granulationScale [[buffer(1)]],
                                     constant float &flowSpeed [[buffer(2)]],
                                     constant float3 &limbCoeffs [[buffer(3)]],
                                     constant float &spotThreshold [[buffer(4)]]) {
    // Centered UV for noise sampling
    float2 uv = in.texCoord * 2.0 - 1.0;

    // Advect UVs using a flow map generated from FBM
    float2 flow = fbm2(float3(uv * granulationScale, time * flowSpeed));
    uv += flow * 0.05;

    // Granulation using mixed low and high frequency noise
    float gLow = fbm(float3(uv * granulationScale, time * flowSpeed));
    float gHigh = fbm(float3(uv * granulationScale * 5.0, time * flowSpeed * 2.0));
    float granulation = gLow * 0.7 + gHigh * 0.3;

    // Sunspot mask with soft penumbra
    float spotNoise = fbm(float3(uv * granulationScale * 0.5, time * flowSpeed * 0.2));
    float spotMask = smoothstep(spotThreshold, spotThreshold + 0.05, spotNoise);

    // Limb darkening based on view angle
    float3 viewDir = normalize(-in.worldPos);
    float mu = saturate(dot(normalize(in.normal), viewDir));
    float intensity = limbCoeffs.x + limbCoeffs.y * mu + limbCoeffs.z * mu * mu;

    float3 baseColor = float3(1.0, 0.9, 0.6);
    float3 color = baseColor * (1.0 + granulation) * intensity * spotMask;
    return float4(color, 1.0);
}
