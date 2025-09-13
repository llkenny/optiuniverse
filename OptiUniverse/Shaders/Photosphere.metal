#include <metal_stdlib>
using namespace metal;

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

struct SunParams {
    float time;
    float2 flowScale;
    float flowSpeed;
    float mixLowHigh;
    float granulationScale;
    float k;
    float gamma;
};

inline float2 decodeFlow(float2 rg01) { return rg01 * 2.0 - 1.0; }

inline float sample3D(texture3d<float, access::sample> vol, sampler s, float3 uvw) {
    return vol.sample(s, fract(uvw)).r;
}

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

fragment float4 sun_surface_fragment(VertexOut in [[stage_in]],
                                     constant SunParams &params [[buffer(0)]],
                                     constant float &deltaTime [[buffer(1)]],
                                     texture3d<float> noiseLow3D [[texture(0)]],
                                     texture3d<float> noiseHigh3D [[texture(1)]],
                                     texture2d<float> flowMap [[texture(2)]],
                                     texture2d<float> sunspotMask [[texture(3)]],
                                     sampler sampLinearWrap [[sampler(0)]]) {
    float2 uv = in.texCoord;

    float2 flow = decodeFlow(flowMap.sample(sampLinearWrap, uv * params.flowScale).rg);
    float2 advUV = fract(uv + flow * params.flowSpeed * deltaTime);

    float3 gUVW = float3(advUV, params.time * 0.03) * (1.0 / max(params.granulationScale, 1e-6));
    float low  = sample3D(noiseLow3D,  sampLinearWrap, gUVW);
    float high = sample3D(noiseHigh3D, sampLinearWrap, gUVW);
    float gran = mix(low, high, params.mixLowHigh);

    float m = sunspotMask.sample(sampLinearWrap, uv).r;
    float outMask = 1.0 - params.k * pow(saturate(1.0 - m), params.gamma);

    float emissive = saturate(0.4 + 0.6 * gran);
    emissive *= saturate(outMask);

    float3 color = float3(1.0, 0.7, 0.5) * emissive;
    return float4(color, 1.0);
}

