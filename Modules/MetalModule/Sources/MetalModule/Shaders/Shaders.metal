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
    float3 lightPosition;
    float cartoonShaderIntensity;
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

float toonLightBand(float lightAmount) {
    float light = saturate(lightAmount);
    if (light < 0.18) {
        return 0.18;
    }
    if (light < 0.45) {
        return 0.42;
    }
    if (light < 0.74) {
        return 0.72;
    }
    return 1.0;
}

float3 adjustSaturation(float3 color, float saturation) {
    float luminance = dot(color, float3(0.299, 0.587, 0.114));
    return mix(float3(luminance), color, saturation);
}

float luminance(float3 color) {
    return dot(color, float3(0.299, 0.587, 0.114));
}

float3 posterizeColor(float3 color, float levels) {
    return floor(color * levels + 0.5) / levels;
}

float textureInkLine(texture2d<float> baseTexture,
                     sampler textureSampler,
                     float2 uv) {
    float2 texelSize = 1.0 / float2(max(float(baseTexture.get_width()), 1.0),
                                    max(float(baseTexture.get_height()), 1.0));
    texelSize *= 1.35;

    float left = luminance(baseTexture.sample(textureSampler, uv - float2(texelSize.x, 0.0)).rgb);
    float right = luminance(baseTexture.sample(textureSampler, uv + float2(texelSize.x, 0.0)).rgb);
    float up = luminance(baseTexture.sample(textureSampler, uv + float2(0.0, texelSize.y)).rgb);
    float down = luminance(baseTexture.sample(textureSampler, uv - float2(0.0, texelSize.y)).rgb);
    float diagA = luminance(baseTexture.sample(textureSampler, uv + texelSize).rgb);
    float diagB = luminance(baseTexture.sample(textureSampler, uv - texelSize).rgb);
    float diagC = luminance(baseTexture.sample(textureSampler, uv + float2(texelSize.x, -texelSize.y)).rgb);
    float diagD = luminance(baseTexture.sample(textureSampler, uv + float2(-texelSize.x, texelSize.y)).rgb);

    float edge = max(max(abs(left - right), abs(up - down)),
                     max(abs(diagA - diagB), abs(diagC - diagD)));
    return smoothstep(0.025, 0.115, edge);
}

float3 cartoonShade(float3 litColor,
                    float3 albedo,
                    float3 emissive,
                    float3 normal,
                    float3 viewDir,
                    float nDotL,
                    float ambientOcclusion,
                    float textureLine,
                    float intensity) {
    float bandedLight = toonLightBand(nDotL);
    float3 saturatedAlbedo = adjustSaturation(albedo, mix(1.0, 1.18, intensity));
    float3 drawnAlbedo = posterizeColor(saturatedAlbedo, mix(8.0, 5.0, intensity));
    float lightingRamp = mix(0.78, 1.08, bandedLight);
    float3 toonColor = drawnAlbedo * lightingRamp * max(ambientOcclusion, 0.58);
    toonColor += emissive;

    float textureInk = textureLine * mix(0.0, 0.48, intensity);
    toonColor = mix(toonColor, toonColor * 0.42, textureInk);

    float silhouette = smoothstep(0.34, 0.64, 1.0 - saturate(abs(dot(normal, viewDir))));
    float3 inkColor = float3(0.0);
    toonColor = mix(toonColor, inkColor, silhouette * mix(0.0, 0.92, intensity));
    toonColor = max((toonColor - 0.03) * mix(1.0, 1.18, intensity) + 0.03, 0.0);

    return mix(litColor, toonColor, intensity);
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
    float textureLine = 0.0;
    if (planetTexture.get_width() > 2 && planetTexture.get_height() > 2) {
        textureLine = textureInkLine(planetTexture, textureSampler, uv);
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
    float nDotL = saturate(dot(lightingNormal, lightDir));
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
    float3 directLight = (diffuse + specular) * nDotL * 2.0;
    float3 ambient = albedo * 0.05 * ambientOcclusion;

    float3 emissive = float3(0.0);
    if (emissiveTexture.get_width() > 0) {
        emissive = emissiveTexture.sample(textureSampler, uv).rgb;
    }

    float3 litColor = ambient + directLight + emissive;
    if (materialUniforms.unlit > 0.5) {
        litColor = albedo + emissive;
    }
    if (materialUniforms.whiteAlbedo > 0.5) {
        litColor = albedo * (0.05 + cloudLight * 1.35);
    }
    float cartoonIntensity = saturate(fragmentUniforms.cartoonShaderIntensity);
    if (cartoonIntensity > 0.0) {
        litColor = cartoonShade(litColor,
                                albedo,
                                emissive,
                                lightingNormal,
                                viewDir,
                                nDotL,
                                ambientOcclusion,
                                textureLine,
                                cartoonIntensity);
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

    fragment float4 tonemap_fragment(FullscreenOut in [[stage_in]],
                                     texture2d<float> hdrTexture [[texture(0)]]) {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        float3 hdr = hdrTexture.sample(s, in.uv).rgb;
        float3 mapped = hdr / (hdr + 1.0);
        return float4(mapped, 1.0);
    }
