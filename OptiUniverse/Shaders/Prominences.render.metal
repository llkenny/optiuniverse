#include <metal_stdlib>
using namespace metal;

struct VSIn {
    float3 worldPos;
    float2 corner;
    float  scale;
    float  startPhase;
    float  fpsMul;
};

struct VSOut {
    float4 pos [[position]];
    float2 uv;
    float  framePhase;
};

struct Camera {
    float4x4 viewProj;
    float3 camRight;
    float3 camUp;
};

struct ProminenceParams {
    float time;
    float flipFps;
    int   cols;
    int   rows;
    float intensity;
    float hueShift;
    float2 noiseUV;
};

vertex VSOut prom_vertex(VSIn in [[stage_in]],
                         constant Camera &cam [[buffer(1)]],
                         constant ProminenceParams &P [[buffer(2)]]) {
    VSOut o;
    float3 right = normalize(cam.camRight);
    float3 up = normalize(cam.camUp);
    float2 size = in.corner * in.scale;
    float3 pos = in.worldPos + right * size.x + up * size.y;
    o.pos = cam.viewProj * float4(pos, 1.0);
    o.uv = in.corner * float2(1.0, -1.0) + 0.5;
    o.framePhase = in.startPhase + (P.time * P.flipFps * in.fpsMul);
    return o;
}

float3 hueShift(float3 c, float shift) {
    return c; // placeholder
}

fragment float4 prom_fragment(VSOut in [[stage_in]],
                              texture2d<float> flipbook [[texture(0)]],
                              texture2d<float> noiseTex [[texture(1)]],
                              sampler sLin [[sampler(0)]],
                              constant ProminenceParams &P [[buffer(0)]]) {
    int total = P.cols * P.rows;
    float f = floor(fract(in.framePhase) * float(total));
    int idx = int(f) % total;
    int cx = idx % P.cols;
    int cy = idx / P.cols;
    float2 cellSize = float2(1.0 / float(P.cols), 1.0 / float(P.rows));
    float2 base = float2(cx, cy) * cellSize;
    float2 uv = base + in.uv * cellSize;
    float4 s = flipbook.sample(sLin, uv);
    float n = noiseTex.sample(sLin, uv * P.noiseUV + P.time * 0.2).r;
    float intensity = P.intensity * (0.9 + 0.2 * n);
    float3 col = hueShift(s.rgb * intensity, P.hueShift);
    return float4(col, s.a * intensity);
}

