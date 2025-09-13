#include <metal_stdlib>
using namespace metal;

struct VSIn {
    float3 worldPos;
    float2 corner;
    float  scale;
    float  startPhase;
    float  fpsMul;
    float3 pad;
};

struct VSOut {
    float4 pos [[position]];
    float2 uv;
    float  framePhase;
    float  vScale;
};

struct Camera {
    float4x4 viewProj;
    float3   camRight;
    float    pad0;
    float3   camUp;
    float    pad1;
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

vertex VSOut promVS(uint vid [[vertex_id]],
                    const device VSIn *in [[buffer(0)]],
                    constant Camera &cam [[buffer(1)]],
                    constant ProminenceParams &P [[buffer(2)]]) {
    VSIn v = in[vid];
    VSOut o;
    float3 right = normalize(cam.camRight);
    float3 up    = normalize(cam.camUp);
    float2 size = v.corner * v.scale;
    float3 pos = v.worldPos + right * size.x + up * size.y;
    o.pos = cam.viewProj * float4(pos, 1.0);
    o.uv = v.corner * float2(1.0, -1.0) + 0.5;
    float total = float(P.cols * P.rows);
    o.framePhase = v.startPhase + (P.time * P.flipFps * v.fpsMul) / total;
    o.vScale = v.scale;
    return o;
}

fragment float4 promFS(VSOut in [[stage_in]],
                       texture2d<float> flipbook [[texture(0)]],
                       texture2d<float> noiseTex [[texture(1)]],
                       sampler sLin [[sampler(0)]],
                       constant ProminenceParams &P [[buffer(1)]]) {
    int total = P.cols * P.rows;
    float f = floor(fract(in.framePhase) * float(total));
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
