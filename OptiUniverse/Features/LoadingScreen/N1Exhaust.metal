#include <metal_stdlib>
using namespace metal;

// Bounded displacement preserves the plume's attachment point and its transparent margins.
[[ stitchable ]] float2 n1Exhaust(float2 position, float time, float2 size) {
    float height = max(size.y, 1.0);
    float depth = clamp(position.y / height, 0.0, 1.0);
    float wave = sin(position.y * 0.073 - time * 19.0 + position.x * 0.083)
        + 0.45 * sin(position.y * 0.151 + time * 27.0 - position.x * 0.057);
    return position + float2(wave * 2.4 * depth, 0.0);
}
