#include <metal_stdlib>
using namespace metal;

struct ProminenceParticle {
    float3 position;
    float  angle;
    float  life;
};

struct VertexOut {
    float4 position [[position]];
    float  life;
    float  angle;
    float  pointSize [[point_size]];
};

vertex VertexOut prominence_vertex(
    const device ProminenceParticle *particles [[buffer(0)]],
    constant float4x4 &mvpMatrix [[buffer(1)]],
    constant float    &sunRadius [[buffer(2)]],
    constant float    &lifetime  [[buffer(3)]],
    uint id [[vertex_id]]) {

    ProminenceParticle p = particles[id];
    VertexOut out;
    out.position = mvpMatrix * float4(p.position * sunRadius, 1.0);
    out.life = p.life;
    out.angle = p.angle;
    float age = 1.0 - p.life / lifetime;
    out.pointSize = 20.0 + (1.0 - age) * 40.0;
    return out;
}

fragment float4 prominence_fragment(VertexOut in [[stage_in]],
                                    float2 pointCoord [[point_coord]],
                                    constant float &lifetime [[buffer(0)]],
                                    constant float &time [[buffer(1)]],
                                    constant int   &frameCount [[buffer(2)]],
                                    constant float &fps [[buffer(3)]],
                                    texture2d<float> flipbook [[texture(0)]],
                                    sampler samp [[sampler(0)]]) {
    float age = 1.0 - in.life / lifetime;
    float alpha = (1.0 - age) * (1.0 - age);
    float N = float(frameCount);
    float frame = floor(fmod(time * fps + in.angle / (2.0 * M_PI_F) * N, N));
    float vStep = 1.0 / N;
    float2 uv = float2(pointCoord.x, pointCoord.y / N + frame * vStep);
    float4 color = flipbook.sample(samp, uv);
    return float4(color.rgb * alpha, color.a * alpha);
}

