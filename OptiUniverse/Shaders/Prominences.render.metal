#include <metal_stdlib>
using namespace metal;

struct ProminenceParticle {
    float3 position;
    float  angle;
    float  life;
    float  pad;  // padding for 16-byte alignment
};

struct VertexOut {
    float4 position [[position]];
    float  life;
    float  pointSize [[point_size]];
};

vertex VertexOut prominence_vertex(
    const device ProminenceParticle *particles [[buffer(0)]],
    constant float4x4 &mvpMatrix [[buffer(1)]],
    constant float    &lifetime  [[buffer(2)]],
    uint id [[vertex_id]]) {

    ProminenceParticle p = particles[id];
    VertexOut out;
    out.position = mvpMatrix * float4(p.position, 1.0);
    out.life = p.life;
    float age = 1.0 - p.life / lifetime;
    out.pointSize = 1.0 + (1.0 - age) * 2.0;
    return out;
}

fragment float4 prominence_fragment(VertexOut in [[stage_in]],
                                    float2 pointCoord [[point_coord]],
                                    constant float &lifetime [[buffer(0)]],
                                    constant float &time [[buffer(1)]],
                                    texture2d<float> flipbook [[texture(0)]],
                                    sampler samp [[sampler(0)]]) {
    constexpr int N = 16;
    constexpr float fps = 13.5;
    float frame = floor(fmod(time * fps, float(N)));
    float vStep = 1.0 / float(N);
    float2 uv = float2(pointCoord.x, pointCoord.y / float(N) + frame * vStep);
    float4 tex = flipbook.sample(samp, uv);
    float age = 1.0 - in.life / lifetime;
    float alpha = tex.a * (1.0 - age);
    return float4(tex.rgb * alpha, alpha); // Additive blending expected
}

