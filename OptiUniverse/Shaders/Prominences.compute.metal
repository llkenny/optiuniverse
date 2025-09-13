#include <metal_stdlib>
using namespace metal;

struct ProminenceParticle {
    float3 position;
    float  angle;   // angle around the sun's limb
    float  life;    // remaining life time
    float  pad;     // padding for 16-byte alignment
};

// Simple deterministic pseudo-random generator
static float rand(float x) {
    return fract(sin(x) * 43758.5453);
}

kernel void updateProminenceParticles(
    device ProminenceParticle *particles [[buffer(0)]],
    constant uint            &particleCount [[buffer(1)]],
    constant float           &arcHeight     [[buffer(2)]],
    constant float           &lifetime      [[buffer(3)]],
    constant float           &time          [[buffer(4)]],
    constant float           &delta         [[buffer(5)]],
    uint id [[thread_position_in_grid]]) {

    if (id >= particleCount) return;

    ProminenceParticle p = particles[id];
    p.life -= delta;

    // Respawn when life ends
    if (p.life <= 0.0) {
        float seed = rand(float(id) + time);
        p.angle = seed * 2.0 * M_PI_F;
        p.life = lifetime;
    }

    float progress = 1.0 - p.life / lifetime; // 0 at spawn -> 1 at death

    // Base position on the limb
    float3 base = float3(cos(p.angle), 0.0, sin(p.angle));

    // Semi-circular arc
    float height = sin(progress * M_PI_F) * arcHeight;
    float radial = 1.0 + (1.0 - cos(progress * M_PI_F)) * 0.1;

    p.position = base * radial;
    p.position.y = height;

    particles[id] = p;
}

