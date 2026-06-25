//
//  StarFieldGenerator.swift
//  UniverseModule
//
//  Created by max on 04.05.2026.
//

import simd

enum StarFieldGenerator {
    static func makeStars(configuration: StarFieldConfiguration = StarFieldConfiguration()) -> [StarVertex] {
        let count = configuration.starCount
        guard count > 0, !configuration.colorPalette.isEmpty else { return [] }

        var random = SeededRandom(seed: configuration.seed)
        var stars: [StarVertex] = []
        stars.reserveCapacity(count)

        let innerRadius = min(configuration.innerRadius, configuration.outerRadius)
        let outerRadius = max(configuration.innerRadius, configuration.outerRadius)
        let minimumBrightness = min(configuration.minimumBrightness, configuration.maximumBrightness)
        let maximumBrightness = max(configuration.minimumBrightness, configuration.maximumBrightness)
        let minimumPointSize = min(configuration.minimumPointSize, configuration.maximumPointSize)
        let maximumPointSize = max(configuration.minimumPointSize, configuration.maximumPointSize)

        for _ in 0..<count {
            let radius = random.nextFloat(in: innerRadius...outerRadius)
            let zValue = random.nextFloat(in: -1...1)
            let azimuth = random.nextFloat(in: 0...(2 * .pi))
            let xyRadius = sqrt(max(0, 1 - zValue * zValue))
            let direction = SIMD3<Float>(
                cos(azimuth) * xyRadius,
                sin(azimuth) * xyRadius,
                zValue
            )
            let paletteIndex = min(
                Int(random.nextUnitFloat() * Float(configuration.colorPalette.count)),
                configuration.colorPalette.count - 1
            )
            let color = configuration.colorPalette[paletteIndex]
            let brightness = random.nextFloat(in: minimumBrightness...maximumBrightness)
            let pointSize = random.nextFloat(in: minimumPointSize...maximumPointSize)

            stars.append(
                StarVertex(
                    positionAndSize: SIMD4<Float>(direction * radius, pointSize),
                    colorAndBrightness: SIMD4<Float>(color, brightness)
                )
            )
        }

        return stars
    }

    private struct SeededRandom {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func nextUnitFloat() -> Float {
            let value = nextUInt64() >> 40
            return Float(value) / Float(1 << 24)
        }

        mutating func nextFloat(in range: ClosedRange<Float>) -> Float {
            range.lowerBound + nextUnitFloat() * (range.upperBound - range.lowerBound)
        }

        private mutating func nextUInt64() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
    }
}
