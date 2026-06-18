import Testing
@testable import UniverseModule

@Test func filmicPostFXPresetUsesControlledCinematicDefaults() {
    let preset = PostFXParams.filmic

    #expect(preset.style == 2)
    #expect(preset.bloomThreshold == 0.72)
    #expect(preset.bloomRadius == 1.22)
    #expect(preset.dreamyIntensity == 0.0)
    #expect(preset.softFocusRadius == 0.85)
    #expect(preset.hazeStrength == 0.0)
    #expect(preset.saturationBoost == 1.06)
    #expect(preset.vignetteStrength == 0.18)
    #expect(preset.contrast == 1.06)
}

@Test func postFXPresetStylesMatchRendererStyleRawValues() {
    #expect(PostFXParams.standard.style == 0)
    #expect(PostFXParams.dreamy.style == 1)
    #expect(PostFXParams.filmic.style == 2)
}
