#include <metal_stdlib>
using namespace metal;

// Simple hash function for generating pseudo-random numbers
static float hash11(float p) {
    return fract(sin(p * 43758.5453) * 143758.5453);
}

struct VertexOut {
    float4 position [[position]];
    float3 worldPos;
};

struct CoronaUniforms {
    float3 cameraPos;
    float3 sunPos;
    float  innerRadius;
    float  outerRadius;
    float  time;
    uint   stepCount;  // Ray-march steps, controlled by quality preset
    float  intensity;
};

fragment float4 corona_raymarch_fragment(VertexOut in [[stage_in]],
                                         constant CoronaUniforms &uni [[buffer(0)]],
                                         texture2d<float> blueNoise [[texture(0)]],
                                         sampler noiseSampler [[sampler(0)]]) {
    // Direction from camera through this fragment
    float3 rayDir = normalize(in.worldPos - uni.cameraPos);
    float3 oc = uni.cameraPos - uni.sunPos;

    // Intersections with outer shell
    float b = dot(rayDir, oc);
    float c = dot(oc, oc) - uni.outerRadius * uni.outerRadius;
    float disc = b*b - c;
    if (disc < 0.0) {
        discard_fragment();
    }
    float tFar = -b + sqrt(disc);

    // Intersections with inner shell
    float cInner = dot(oc, oc) - uni.innerRadius * uni.innerRadius;
    float discInner = b*b - cInner;
    float tNear = max(0.0, -b - sqrt(max(discInner, 0.0)));

    // Blue-noise based jitter along the ray
    float2 noiseUV = fract(in.position.xy * 0.5);
    float jitter = blueNoise.sample(noiseSampler, noiseUV).r;
    jitter += hash11(uni.time + in.position.x + in.position.y);

    float travel = tFar - tNear;
    float step = travel / float(uni.stepCount);
    float t = tNear + step * jitter;

    float3 accum = float3(0.0);
    float transmittance = 1.0;

    for (uint i = 0; i < uni.stepCount; ++i) {
        if (transmittance < 0.01) break; // Early exit when fully opaque
        float3 pos = uni.cameraPos + rayDir * t;
        float r = length(pos - uni.sunPos);
        float shell = (r - uni.innerRadius) / (uni.outerRadius - uni.innerRadius);
        float density = exp(-shell * 6.0);

        float3 col = float3(1.0, 0.8, 0.3) * density;
        accum += transmittance * col;
        transmittance *= 1.0 - density * 0.05;
        t += step;
    }

    return float4(accum * uni.intensity, 1.0);
}

