//
//  StarVertex.swift
//  MetalModule
//
//  Created by max on 04.05.2026.
//


struct StarVertex: Sendable {
    var positionAndSize: SIMD4<Float>
    var colorAndBrightness: SIMD4<Float>

    var position: SIMD3<Float> {
        SIMD3<Float>(positionAndSize.x, positionAndSize.y, positionAndSize.z)
    }

    var pointSize: Float {
        positionAndSize.w
    }

    var color: SIMD3<Float> {
        SIMD3<Float>(colorAndBrightness.x, colorAndBrightness.y, colorAndBrightness.z)
    }

    var brightness: Float {
        colorAndBrightness.w
    }
}