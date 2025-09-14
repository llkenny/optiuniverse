#include <metal_stdlib>
using namespace metal;

struct ProminenceParams {
    float time;
    float flipFps;
    int cols;
    int rows;
    float intensity;
    float hueShift;
    float2 noiseUV;
};

struct VSIn {
    float3 worldPos [[attribute(0)]];
    float2 corner    [[attribute(1)]];
    float  scale     [[attribute(2)]];
    float  startPhase[[attribute(3)]];
    float  fpsMul    [[attribute(4)]];
};

struct VSOut {
    float4 pos [[position]];
    float2 uv;
    float  framePhase;
    float  vScale;
};

struct Camera {
    float4x4 viewProj;
    float4x4 model;
    float3 camRight;
    float3 camUp;
};

vertex VSOut promVS(VSIn in [[stage_in]],
                    constant Camera& cam [[buffer(0)]],
                    constant ProminenceParams& P [[buffer(1)]]) {
    VSOut o;
    float3 right = normalize(cam.camRight);
    float3 up = normalize(cam.camUp);
    float2 size = in.corner * in.scale;
    float4 worldCenter = cam.model * float4(in.worldPos, 1.0);
    float3 pos = worldCenter.xyz + right * size.x + up * size.y;
    o.pos = cam.viewProj * float4(pos, 1.0);
    o.uv = in.corner * float2(1, -1) + 0.5;
    o.framePhase = in.startPhase + (P.time * P.flipFps * in.fpsMul);
    o.vScale = in.scale;
    return o;
}

fragment float4 promFS(VSOut in [[stage_in]],
                       texture2d<float> flipbook [[texture(0)]],
                       texture2d<float> noiseTex [[texture(1)]],
                       sampler sLin [[sampler(0)]],
                       constant ProminenceParams& P [[buffer(1)]]) {
    int total = P.cols * P.rows;
    float phase = fract(in.framePhase);
    float f = floor(phase * total);
    int idx = int(f) % total;
    int cx = idx % P.cols;
    int cy = idx / P.cols;
    float2 cellSize = 1.0 / float2(P.cols, P.rows);
    float2 base = float2(cx, cy) * cellSize;
    float2 uv = base + in.uv * cellSize;
    float4 s = flipbook.sample(sLin, uv);
    float n = noiseTex.sample(sLin, uv * P.noiseUV + P.time * 0.2).r;
    float intensity = P.intensity * (0.9 + 0.2 * n);
    float3 col = s.rgb * intensity;
    return float4(col, s.a * intensity);
}
