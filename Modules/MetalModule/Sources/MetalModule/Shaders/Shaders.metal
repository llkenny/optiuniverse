//
//  VertexIn.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//


// Shaders.metal
#include <metal_stdlib>
using namespace metal;

// Simple hash-based noise for FBM
float hash(float3 p) {
    return fract(sin(dot(p, float3(12.9898, 78.233, 37.719))) * 43758.5453);
}

// Low-iteration FBM returning a 2D warp vector to keep performance high
float2 fbm(float3 p) {
    float2 value = float2(0.0);
    float amplitude = 0.5;
    for (int i = 0; i < 3; ++i) {
        value += amplitude * float2(hash(p), hash(p + 1.0));
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

struct VertexIn {
    float4 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
    float4 tangent [[attribute(3)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 localPosition;
    float2 texCoord;
    float3 normal;
    float3 worldPos;
    float3 worldTangent;
    float3 worldBitangent;
};

struct StarVertexIn {
    float4 positionAndSize;
    float4 colorAndBrightness;
};

struct StarUniforms {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float3 sceneOrigin;
    float time;
};

struct StarVertexOut {
    float4 position [[position]];
    float3 color;
    float pointSize [[point_size]];
};

struct MaterialUniforms {
    float3 baseColorFactor;
    float opacityFactor;
    float roughnessFactor;
    float metallicFactor;
    float ambientOcclusionFactor;
    float usesBaseColorAlpha;
    float usesOpacityTexture;
    float rimAlphaStrength;
    float unlit;
    float whiteAlbedo;
    float alphaGeometryRadius;
};

struct FragmentUniforms {
    float3 cameraPosition;
    float exposureScale;
    float3 lightPosition;
    float3 keyLightColor;
    float terminatorSoftness;
    float3 fillLightColor;
    float rimStrength;
    float3 ambientLightColor;
    float limbDarkening;
    float3 rimLightColor;
    float padding;
};

float distributionGGX(float3 normal, float3 halfVector, float roughness) {
    float alpha = roughness * roughness;
    float alphaSquared = alpha * alpha;
    float nDotH = saturate(dot(normal, halfVector));
    float nDotHSquared = nDotH * nDotH;
    float denominator = nDotHSquared * (alphaSquared - 1.0) + 1.0;
    return alphaSquared / max(3.14159265 * denominator * denominator, 1e-4);
}

float geometrySchlickGGX(float nDotV, float roughness) {
    float k = pow(roughness + 1.0, 2.0) / 8.0;
    return nDotV / max(nDotV * (1.0 - k) + k, 1e-4);
}

float geometrySmith(float3 normal, float3 viewDir, float3 lightDir, float roughness) {
    float nDotV = saturate(dot(normal, viewDir));
    float nDotL = saturate(dot(normal, lightDir));
    float ggxView = geometrySchlickGGX(nDotV, roughness);
    float ggxLight = geometrySchlickGGX(nDotL, roughness);
    return ggxView * ggxLight;
}

float3 fresnelSchlick(float cosTheta, float3 f0) {
    return f0 + (1.0 - f0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

vertex VertexOut vertex_main(
                             const VertexIn in [[stage_in]],
                             constant float4x4 &mvpMatrix [[buffer(5)]],
                             constant float4x4 &modelMatrix [[buffer(6)]],
                             constant float4x4 &worldMatrix [[buffer(7)]]
                             ) {
    VertexOut out;
    out.position = mvpMatrix * in.position;
    out.localPosition = in.position.xyz;
    out.worldPos = (worldMatrix * in.position).xyz;
    out.normal = normalize((modelMatrix * float4(in.normal, 0.0)).xyz);
    out.worldTangent = normalize((modelMatrix * float4(in.tangent.xyz, 0.0)).xyz);
    out.worldBitangent = normalize(cross(out.normal, out.worldTangent) * in.tangent.w);
    out.texCoord = in.texCoord;
    return out;
}

vertex StarVertexOut star_vertex(const device StarVertexIn *stars [[buffer(0)]],
                                 constant StarUniforms &uniforms [[buffer(1)]],
                                 uint vid [[vertex_id]]) {
    StarVertexIn star = stars[vid];
    float3 localPosition = star.positionAndSize.xyz - uniforms.sceneOrigin;
    float4 viewPosition = uniforms.viewMatrix * float4(localPosition, 1.0);

    StarVertexOut out;
    out.position = uniforms.projectionMatrix * viewPosition;
    float twinklePhase = hash(star.positionAndSize.xyz * 0.013);
    float twinkle = 0.97 + 0.03 * sin(uniforms.time * 0.42 + twinklePhase * 6.2831853);
    out.color = star.colorAndBrightness.rgb * star.colorAndBrightness.a * twinkle;
    out.pointSize = star.positionAndSize.w;
    return out;
}

fragment float4 star_fragment(StarVertexOut in [[stage_in]],
                              float2 pointCoord [[point_coord]]) {
    float2 centeredCoord = pointCoord * 2.0 - 1.0;
    float radius = length(centeredCoord);
    float alpha = smoothstep(1.0, 0.35, radius);
    if (alpha <= 0.001) {
        discard_fragment();
    }

    float core = smoothstep(1.0, 0.0, radius);
    float3 color = in.color * mix(0.72, 1.0, core);
    return float4(color, alpha);
}

struct TransferOrbitVertexIn {
    float4 positionAndProgress;
};

struct TransferOrbitUniforms {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4 sceneOriginAndOpacity;
    float4 color;
    float4 dash;
};

struct TransferOrbitVertexOut {
    float4 position [[position]];
    float progress;
};

vertex TransferOrbitVertexOut transfer_orbit_vertex(
                                                    const device TransferOrbitVertexIn *vertices [[buffer(0)]],
                                                    constant TransferOrbitUniforms &uniforms [[buffer(1)]],
                                                    uint vid [[vertex_id]]
                                                    ) {
    TransferOrbitVertexIn orbitVertex = vertices[vid];
    float3 sceneOrigin = uniforms.sceneOriginAndOpacity.xyz;
    float3 localPosition = orbitVertex.positionAndProgress.xyz - sceneOrigin;

    TransferOrbitVertexOut out;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * float4(localPosition, 1.0);
    out.progress = orbitVertex.positionAndProgress.w;
    return out;
}

fragment float4 transfer_orbit_fragment(TransferOrbitVertexOut in [[stage_in]],
                                        constant TransferOrbitUniforms &uniforms [[buffer(0)]]) {
    if (uniforms.dash.x > 0.0) {
        float dashPhase = fract(in.progress * uniforms.dash.x);
        if (dashPhase > uniforms.dash.y) {
            discard_fragment();
        }
    }

    float pulse = 0.76 + 0.24 * sin(in.progress * 3.14159265);
    float alpha = uniforms.color.a * uniforms.sceneOriginAndOpacity.w;
    return float4(uniforms.color.rgb * pulse, alpha);
}

struct RouteMarkerVertexIn {
    float4 positionAndProgress;
};

struct RouteMarkerUniforms {
    float4x4 viewMatrix;
    float4x4 projectionMatrix;
    float4 sceneOriginAndOpacity;
    float4 color;
    float4 params;
};

struct RouteMarkerVertexOut {
    float4 position [[position]];
    float progress;
    float pointSize [[point_size]];
};

vertex RouteMarkerVertexOut route_marker_vertex(const device RouteMarkerVertexIn *vertices [[buffer(0)]],
                                                constant RouteMarkerUniforms &uniforms [[buffer(1)]],
                                                uint vid [[vertex_id]]) {
    RouteMarkerVertexIn routeVertex = vertices[vid];
    float3 sceneOrigin = uniforms.sceneOriginAndOpacity.xyz;
    float3 localPosition = routeVertex.positionAndProgress.xyz - sceneOrigin;

    RouteMarkerVertexOut out;
    out.position = uniforms.projectionMatrix * uniforms.viewMatrix * float4(localPosition, 1.0);
    out.progress = routeVertex.positionAndProgress.w;
    out.pointSize = uniforms.params.y + 2.5 * sin(uniforms.params.x * 6.0);
    return out;
}

fragment float4 route_marker_fragment(RouteMarkerVertexOut in [[stage_in]],
                                      constant RouteMarkerUniforms &uniforms [[buffer(0)]],
                                      float2 pointCoord [[point_coord]]) {
    float2 centeredCoord = pointCoord * 2.0 - 1.0;
    float radius = length(centeredCoord);
    float outerMask = 1.0 - smoothstep(0.90, 1.0, radius);
    float innerMask = smoothstep(0.58, 0.70, radius);
    float ring = outerMask * innerMask;
    float glow = (1.0 - smoothstep(0.70, 1.0, radius)) * 0.22;
    float alpha = (ring + glow) * uniforms.sceneOriginAndOpacity.w;
    if (alpha <= 0.001) {
        discard_fragment();
    }

    float pulse = 0.82 + 0.18 * sin(uniforms.params.x * 8.0);
    float3 color = uniforms.color.rgb * (pulse + ring * 0.55);
    return float4(color, alpha);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              texture2d<float> planetTexture [[texture(0)]],
                              texture2d<float> normalTexture [[texture(1)]],
                              texture2d<float> emissiveTexture [[texture(2)]],
                              texture2d<float> roughnessTexture [[texture(3)]],
                              texture2d<float> metallicTexture [[texture(4)]],
                              texture2d<float> ambientOcclusionTexture [[texture(5)]],
                              texture2d<float> opacityTexture [[texture(6)]],
                              constant FragmentUniforms &fragmentUniforms [[buffer(0)]],
                              constant MaterialUniforms &materialUniforms [[buffer(1)]],
                              sampler textureSampler [[sampler(0)]]) {
    // USD textures arrive with top-left image origin, so flip V before sampling.
    float2 uv = float2(in.texCoord.x, 1.0 - in.texCoord.y);
    float3 albedo = materialUniforms.baseColorFactor;
    float alpha = materialUniforms.opacityFactor;
    float4 colorSample = float4(1.0);
    if (planetTexture.get_width() > 0) {
        colorSample = planetTexture.sample(textureSampler, uv);
        albedo *= colorSample.rgb;
        if (materialUniforms.alphaGeometryRadius < -0.5 &&
            length(in.localPosition) > -materialUniforms.alphaGeometryRadius) {
            discard_fragment();
        }
        if (materialUniforms.alphaGeometryRadius > 0.5 &&
            length(in.localPosition) <= materialUniforms.alphaGeometryRadius) {
            discard_fragment();
        }
        if (materialUniforms.usesBaseColorAlpha > 0.5) {
            alpha *= colorSample.a;
        }
    }
    if (materialUniforms.usesOpacityTexture > 0.5) {
        alpha *= opacityTexture.sample(textureSampler, uv).r;
    }
    if (materialUniforms.whiteAlbedo > 0.5) {
        float cloudCoverage = max(max(colorSample.r, colorSample.g), colorSample.b);
        alpha *= smoothstep(0.08, 0.72, cloudCoverage);
        albedo = float3(1.0);
    }

    float3 normal = normalize(in.normal);
    if (normalTexture.get_width() > 0) {
        float3 normalSample = normalTexture.sample(textureSampler, uv).xyz * 2.0 - 1.0;
        float3x3 tbn = float3x3(normalize(in.worldTangent),
                                normalize(in.worldBitangent),
                                normal);
        normal = normalize(tbn * normalSample);
    }
    float3 lightingNormal = normal;
    if (materialUniforms.whiteAlbedo > 0.5) {
        lightingNormal = -lightingNormal;
    }

    float3 lightDir = normalize(fragmentUniforms.lightPosition - in.worldPos);
    float3 viewDir = normalize(fragmentUniforms.cameraPosition - in.worldPos);
    if (materialUniforms.rimAlphaStrength > 0.0) {
        float rim = 1.0 - saturate(abs(dot(lightingNormal, viewDir)));
        alpha *= pow(rim, materialUniforms.rimAlphaStrength);
    }

    float3 halfVector = normalize(lightDir + viewDir);
    float signedNDotL = dot(lightingNormal, lightDir);
    float nDotL = saturate(signedNDotL);
    float nDotV = saturate(dot(lightingNormal, viewDir));
    float cloudLight = 1.0;
    if (materialUniforms.whiteAlbedo > 0.5) {
        cloudLight = smoothstep(0.03, 0.35, nDotL);
        alpha *= cloudLight;
    }

    float roughness = clamp(materialUniforms.roughnessFactor, 0.04, 1.0);
    if (roughnessTexture.get_width() > 0) {
        roughness *= roughnessTexture.sample(textureSampler, uv).r;
    }
    roughness = clamp(roughness, 0.04, 1.0);

    float metallic = clamp(materialUniforms.metallicFactor, 0.0, 1.0);
    if (metallicTexture.get_width() > 0) {
        metallic *= metallicTexture.sample(textureSampler, uv).r;
    }
    metallic = clamp(metallic, 0.0, 1.0);

    float ambientOcclusion = clamp(materialUniforms.ambientOcclusionFactor, 0.0, 1.0);
    if (ambientOcclusionTexture.get_width() > 0) {
        ambientOcclusion *= ambientOcclusionTexture.sample(textureSampler, uv).r;
    }
    ambientOcclusion = clamp(ambientOcclusion, 0.0, 1.0);

    float3 f0 = mix(float3(0.04), albedo, metallic);
    float3 fresnel = fresnelSchlick(saturate(dot(halfVector, viewDir)), f0);
    float distribution = distributionGGX(normal, halfVector, roughness);
    float geometry = geometrySmith(normal, viewDir, lightDir, roughness);
    float denominator = max(4.0 * nDotV * nDotL, 1e-4);
    float3 specular = (distribution * geometry * fresnel) / denominator;

    float3 kS = fresnel;
    float3 kD = (1.0 - kS) * (1.0 - metallic);
    float3 diffuse = kD * albedo / 3.14159265;
    float keyLight = smoothstep(-fragmentUniforms.terminatorSoftness,
                                1.0,
                                signedNDotL);
    float3 directLight = (diffuse + specular) * keyLight * 2.25 * fragmentUniforms.keyLightColor;
    float fillAmount = (1.0 - keyLight) * saturate(0.25 + nDotV * 0.75);
    float3 fillLight = albedo * fragmentUniforms.fillLightColor * fillAmount * 0.16;
    float3 ambient = albedo * fragmentUniforms.ambientLightColor * ambientOcclusion;

    float3 emissive = float3(0.0);
    if (emissiveTexture.get_width() > 0) {
        emissive = emissiveTexture.sample(textureSampler, uv).rgb;
    }

    float3 litColor = ambient + directLight + fillLight * ambientOcclusion + emissive;
    if (materialUniforms.unlit > 0.5) {
        litColor = albedo + emissive;
    }
    if (materialUniforms.whiteAlbedo > 0.5) {
        litColor = albedo * (0.05 + cloudLight * 1.35);
    }
    if (materialUniforms.unlit <= 0.5) {
        float limb = pow(1.0 - nDotV, 2.0);
        litColor *= 1.0 - fragmentUniforms.limbDarkening * limb;

        float rimVisibility = smoothstep(-0.35, 0.55, signedNDotL);
        float rim = pow(1.0 - nDotV, 2.6) * fragmentUniforms.rimStrength * rimVisibility;
        litColor += fragmentUniforms.rimLightColor * rim;
        litColor *= fragmentUniforms.exposureScale;
    }
    return float4(litColor, alpha);
}

// Specialized fragment shader for the Sun. Produces an animated
// procedural surface and bright corona.
fragment float4 fragment_sun(VertexOut in [[stage_in]],
                             constant float &time [[buffer(0)]],
                             constant float &delta [[buffer(1)]],
                             constant float &exposure [[buffer(2)]],
                             texture2d<float> planetTexture [[texture(0)]],
                             texture2d<float> coronaGradient [[texture(1)]],
                             texture2d<float> coronaNoise [[texture(2)]],
                             sampler textureSampler [[sampler(0)]]) {
    // Center UV on (0,0)
    float2 uv = in.texCoord * 2.0 - 1.0;
    float r = length(uv);

    // Rotate texture coordinates over time for swirling motion
    float angle = time * 0.1 * delta;
    float2 rotUV = float2(uv.x * cos(angle) - uv.y * sin(angle),
                          uv.x * sin(angle) + uv.y * cos(angle));

    // Warp UVs using secondary FBM for more turbulent motion
    float2 warp = fbm(float3(rotUV * 10.0, time * 0.3 * delta));
    rotUV += warp * 0.02;

    // Simple procedural noise modulated by provided noise texture
    float noise = sin((rotUV.x + time) * 20.0 * delta) * sin((rotUV.y - time) * 20.0 * delta);
    noise = noise * 0.5 + 0.5; // Normalize to 0..1
    float noiseTex = coronaNoise.sample(textureSampler, rotUV * 4.0).r;
    noise *= noiseTex;

    // Base color mixed with sampled texture to keep some variation
    float3 base = planetTexture.sample(textureSampler, in.texCoord).rgb;
    float3 surface = base + noise * float3(1.0, 0.6, 0.0);

    // Bright core towards the center
    float core = pow(max(0.0, 1.0 - r), 4.0);
      float3 coreColor = float3(30.0, 15.0, 5.0) * core;

    // Multi-layer corona with height-based falloff and gradient colouring
    float height = max(0.0, r - 1.0);
    float density = exp(-height * 8.0);
    float3 coronaColor = coronaGradient.sample(textureSampler, float2(min(r, 1.0), 0.5)).rgb;
    float3 corona = float3(0.0);
    const float freqs[3] = {1.0, 2.0, 4.0};
    for (int i = 0; i < 3; ++i) {
        float f = freqs[i];
        float layer = sin((rotUV.x + time) * 20.0 * f * delta) * sin((rotUV.y - time) * 20.0 * f * delta);
        layer = layer * 0.5 + 0.5;
        corona += coronaColor * (1.0 / (float(i) + 1.0)) * layer;
    }
    corona *= density * noiseTex;

    float3 color = (surface + coreColor + corona) * exposure;
    return float4(color, 1.0);
}

fragment float4 fragment_main_debug(VertexOut in [[stage_in]]) {
    return float4(in.texCoord.x, in.texCoord.y, 0.0, 1.0);
}

//fragment float4 fragment_main(VertexOut in [[stage_in]]) {
//    return float4(in.texCoord.x, in.texCoord.y, 0.0, 1.0);
//}

fragment float4 basic_fragment() {
    return float4(0, 0, 1, 1);
}

// Axes Shaders in your .metal file
struct AxesVertexOut {
    float4 position [[position]];
    float3 color;
};

vertex AxesVertexOut axes_vertex(
                                 const device packed_float3 *vertices [[buffer(0)]],
                                 constant float4x4 &mvpMatrix [[buffer(1)]],
                                 uint vid [[vertex_id]]
                                 ) {
    AxesVertexOut out;
    float3 position = vertices[vid * 2];     // Position is first 3 floats
    out.color = vertices[vid * 2 + 1];       // Color is next 3 floats
    out.position = mvpMatrix * float4(position, 1.0);
    return out;
}

   fragment float4 axes_fragment(AxesVertexOut in [[stage_in]]) {
        return float4(in.color, 1.0);
    }

    struct FullscreenOut {
        float4 position [[position]];
        float2 uv;
    };

    vertex FullscreenOut fullscreen_vertex(uint vid [[vertex_id]]) {
        float2 pos[3] = {
            float2(-1.0, -1.0),
            float2( 3.0, -1.0),
            float2(-1.0,  3.0)
        };
        FullscreenOut out;
        out.position = float4(pos[vid], 0.0, 1.0);
        out.uv = pos[vid] * 0.5 + 0.5;
        return out;
    }

    struct EnvironmentUniforms {
        float4x4 inverseProjectionMatrix;
        float4x4 inverseViewRotationMatrix;
        float exposure;
        float saturation;
        float2 padding;
    };

    fragment float4 environment_fragment(FullscreenOut in [[stage_in]],
                                         texture2d<float> environmentTexture [[texture(0)]],
                                         constant EnvironmentUniforms &uniforms [[buffer(0)]]) {
        constexpr sampler environmentSampler(filter::linear,
                                             mip_filter::linear,
                                             address::repeat);

        float2 ndc = in.uv * 2.0 - 1.0;
        float4 viewPosition = uniforms.inverseProjectionMatrix * float4(ndc, 1.0, 1.0);
        float3 viewDirection = normalize(viewPosition.xyz / max(abs(viewPosition.w), 1e-4));
        float3 worldDirection = normalize((uniforms.inverseViewRotationMatrix * float4(viewDirection, 0.0)).xyz);

        float longitude = atan2(worldDirection.z, worldDirection.x);
        float latitude = acos(clamp(worldDirection.y, -1.0, 1.0));
        float2 uv = float2(longitude / (2.0 * 3.14159265) + 0.5,
                           latitude / 3.14159265);

        float3 color = environmentTexture.sample(environmentSampler, uv).rgb;
        float3 gray = float3(dot(color, float3(0.299, 0.587, 0.114)));
        color = mix(gray, color, uniforms.saturation);
        color *= uniforms.exposure;

        return float4(color, 1.0);
    }

    fragment float4 tonemap_fragment(FullscreenOut in [[stage_in]],
                                     texture2d<float> hdrTexture [[texture(0)]]) {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        float3 hdr = hdrTexture.sample(s, in.uv).rgb;
        float3 mapped = hdr / (hdr + 1.0);
        return float4(mapped, 1.0);
    }
