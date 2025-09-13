#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 uv;
};

vertex VertexOut corona_vertex(const VertexIn in                 [[stage_in]],
                               constant float4x4 &mvpMatrix       [[buffer(1)]],
                               constant float4x4 &modelMatrix     [[buffer(2)]],
                               constant float    &billboardScale  [[buffer(3)]]) {
    VertexOut out;
    float3 pos = float3(in.position * billboardScale, 0.0);
    out.position = mvpMatrix * float4(pos, 1.0);
    out.uv = in.position * 0.5 + 0.5;
    return out;
}

fragment float4 corona_fragment(VertexOut in              [[stage_in]],
                                constant float &time      [[buffer(0)]],
                                constant float &coronaIntensity [[buffer(1)]],
                                constant float &coronaScale [[buffer(2)]],
                                constant float &flickerSpeed [[buffer(3)]],
                                texture2d<float> coronaGradient [[texture(0)]],
                                texture2d<float> coronaNoise [[texture(1)]],
                                sampler samp [[sampler(0)]]) {
    // Compute radial distance from the quad centre. `in.uv` ranges from
    // 0..1 so distances are in 0..0.707; scale by 2 so the gradient hits
    // zero at the edges of the quad, preventing a square-shaped corona.
    float2 d = in.uv - float2(0.5);
    float r = min(length(d) * 2.0, 1.0);
    float grad = coronaGradient.sample(samp, float2(r, 0.5)).r;

    // Noise introduces subtle flicker but is masked by the radial gradient.
    float flicker = coronaNoise.sample(samp,
                                      in.uv * coronaScale + float2(time * flickerSpeed)).r;
    float corona = grad * (0.8 + 0.2 * flicker);
    float3 color = float3(1.0, 0.8, 0.3) * corona * coronaIntensity;
    return float4(color, grad);
}

