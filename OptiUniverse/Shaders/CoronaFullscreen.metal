#include <metal_stdlib>
using namespace metal;

struct VSIn  { float2 pos [[attribute(0)]]; float2 uv [[attribute(1)]]; };
struct VSOut { float4 pos [[position]];     float2 uv; };

vertex VSOut coronaVS(VSIn in [[stage_in]]) {
    VSOut o;
    o.pos = float4(in.pos, 0, 1);   // NDC quad: (-1..1)
    o.uv  = in.uv;                  // (0..1)
    return o;
}

struct CoronaParams {
    float2 screenCenterUV; // usually (0.5, 0.5) or sun center in screen UV
    float  radius;         // visible radius of disk in UV
    float  width;          // corona thickness in UV
    float  noiseAmt;       // 0..1
    float  time;           // seconds
};

fragment float4 coronaFS(
    VSOut in [[stage_in]],
    constant CoronaParams& P [[buffer(0)]],
    texture2d<float> coronaGradient  [[texture(0)]], // 1D in X: white->black
    texture2d<float> coronaNoise     [[texture(1)]],
    sampler sLin
) {
    // radial coordinates from the center
    float2 d  = in.uv - P.screenCenterUV;
    float  r  = length(d);                // distance from center (in UV)
    float  rr = (r - P.radius) / max(P.width, 1e-4);
    rr = clamp(rr, 0.0, 1.0);

    // gradient lookup
    float g = coronaGradient.sample(sLin, float2(rr, 0.5)).r;

    // slight turbulence
    float n = coronaNoise.sample(sLin, in.uv * 2.0 + P.time * 0.05).r;
    g *= (0.85 + 0.15 * n * P.noiseAmt);

    float3 col = float3(1.0, 0.68, 0.36) * g;
    return float4(col, g);
}
