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
    uint   id [[flat]];
    float  pointSize [[point_size]];
};

vertex VertexOut prominence_vertex(
    const device ProminenceParticle *particles [[buffer(0)]],
    constant float4x4 &mvpMatrix [[buffer(1)]],
    constant float    &lifetime  [[buffer(2)]],
    constant float    &radius    [[buffer(3)]],
    uint id [[vertex_id]]) {

    ProminenceParticle p = particles[id];
    VertexOut out;
    float3 scaled = p.position * radius;
    out.position = mvpMatrix * float4(scaled, 1.0);
    out.life = p.life;
    out.id = id;
    float age = 1.0 - p.life / lifetime;
    out.pointSize = 128.0 + (1.0 - age) * 64.0;
    return out;
}

fragment float4 prominence_fragment(VertexOut in [[stage_in]],
                                    float2 pointCoord [[point_coord]],
                                    constant float &lifetime [[buffer(0)]],
                                    constant float &time [[buffer(1)]],
                                    constant uint  &frameCount [[buffer(2)]],
                                    constant float &fps [[buffer(3)]],
                                    texture2d<float> flipbookTex [[texture(0)]],
                                    sampler flipbookSampler [[sampler(0)]]) {
    float age = 1.0 - in.life / lifetime;
    float frame = floor(fmod(time * fps + float(in.id), float(frameCount)));
    float vStep = 1.0 / float(frameCount);
    float2 uv = float2(pointCoord.x, pointCoord.y / float(frameCount) + frame * vStep);
    float4 tex = flipbookTex.sample(flipbookSampler, uv);
    float alpha = tex.a * (1.0 - age);
    float3 color = tex.rgb * alpha;
    return float4(color, alpha);
}

