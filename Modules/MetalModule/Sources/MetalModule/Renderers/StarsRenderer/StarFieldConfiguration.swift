//
//  StarFieldConfiguration.swift
//  MetalModule
//
//  Created by max on 04.05.2026.
//

struct StarFieldConfiguration: Sendable {
    static let defaultBaseStarCount = 3_200
    static let maximumStarCount = 12_000
    static let defaultPalette: [SIMD3<Float>] = [
        SIMD3<Float>(1.0, 0.94, 0.84),
        SIMD3<Float>(0.72, 0.82, 1.0),
        SIMD3<Float>(1.0, 0.82, 0.62),
        SIMD3<Float>(0.86, 0.92, 1.0),
        SIMD3<Float>(1.0, 1.0, 1.0)
    ]

    var density: Float = 1.25
    var innerRadius: Float = 5_200
    var outerRadius: Float = 8_500
    var seed: UInt64 = 0x5EED_5A1A
    var colorPalette: [SIMD3<Float>] = Self.defaultPalette
    var minimumBrightness: Float = 0.28
    var maximumBrightness: Float = 1.85
    var minimumPointSize: Float = 0.72
    var maximumPointSize: Float = 2.05

    var starCount: Int {
        guard density.isFinite, density > 0 else { return 0 }

        let scaledCount = Int((density * Float(Self.defaultBaseStarCount)).rounded())
        return min(max(scaledCount, 0), Self.maximumStarCount)
    }
}
