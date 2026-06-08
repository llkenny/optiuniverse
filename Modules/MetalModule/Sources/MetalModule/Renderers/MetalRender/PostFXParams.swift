//
//  PostFXParams.swift
//  MetalModule
//
//  Created by max on 20.05.2026.
//

struct PostFXParams {
    var bloomThreshold: Float
    var bloomRadius: Float
    var style: UInt32
    var dreamyIntensity: Float
    var softFocusRadius: Float
    var hazeStrength: Float
    var saturationBoost: Float
    var vignetteStrength: Float
    var contrast: Float
}

extension PostFXParams {
    static let standard = PostFXParams(
        bloomThreshold: 1.0,
        bloomRadius: 1.0,
        style: 0,
        dreamyIntensity: 0.0,
        softFocusRadius: 0.75,
        hazeStrength: 0.0,
        saturationBoost: 1.0,
        vignetteStrength: 0.15,
        contrast: 1.0
    )

    static let dreamy = PostFXParams(
        bloomThreshold: 0.55,
        bloomRadius: 1.35,
        style: 1,
        dreamyIntensity: 0.5,
        softFocusRadius: 1.9,
        hazeStrength: 0.3,
        saturationBoost: 1.08,
        vignetteStrength: 0.08,
        contrast: 0.96
    )

    static let filmic = PostFXParams(
        bloomThreshold: 0.72,
        bloomRadius: 1.22,
        style: 2,
        dreamyIntensity: 0.0,
        softFocusRadius: 0.85,
        hazeStrength: 0.0,
        saturationBoost: 1.06,
        vignetteStrength: 0.18,
        contrast: 1.06
    )
}
