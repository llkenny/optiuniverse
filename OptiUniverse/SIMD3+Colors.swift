//
//  SIMD3+Colors.swift
//  OptiUniverse
//
//  Created by max on 23.07.2025.
//

extension SIMD3 where Scalar == Float {
    // Solar system body colors (approximate RGB values)
    static let sun = SIMD3<Float>(1.00, 0.98, 0.85)  // White with yellow tint
    static let mercury = SIMD3<Float>(0.75, 0.75, 0.75)  // Gray
    static let venus = SIMD3<Float>(0.90, 0.80, 0.60)  // Pale yellow
    static let earth = SIMD3<Float>(0.20, 0.50, 0.80)  // Blue
    static let mars = SIMD3<Float>(0.80, 0.40, 0.20)  // Red-orange
    static let jupiter = SIMD3<Float>(0.80, 0.70, 0.60)  // Beige
    static let saturn = SIMD3<Float>(0.90, 0.85, 0.70)  // Pale gold
    static let uranus = SIMD3<Float>(0.60, 0.80, 0.90)  // Pale blue
    static let neptune = SIMD3<Float>(0.40, 0.50, 0.90)  // Deep blue
}
