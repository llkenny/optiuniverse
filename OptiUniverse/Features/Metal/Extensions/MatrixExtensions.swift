//
//  MatrixExtensions.swift
//  OptiUniverse
//
//  Created by max on 24.07.2025.
//

import simd

extension float4x4 {
    nonisolated static func makeTranslation(_ translation: SIMD3<Float>) -> float4x4 {
        .init(
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [translation.x, translation.y, translation.z, 1]
        )
    }

    nonisolated static func makeRotationX(_ angle: Float) -> float4x4 {
        .init(
            [1, 0, 0, 0],
            [0, cos(angle), -sin(angle), 0],
            [0, sin(angle), cos(angle), 0],
            [0, 0, 0, 1]
        )
    }

    nonisolated static func makeRotationY(_ angle: Float) -> float4x4 {
        .init(
            [cos(angle), 0, -sin(angle), 0],
            [0, 1, 0, 0],
            [sin(angle), 0, cos(angle), 0],
            [0, 0, 0, 1]
        )
    }

    nonisolated static func makeRotationZ(_ angle: Float) -> float4x4 {
        .init(
            [cos(angle), sin(angle), 0, 0],
            [-sin(angle), cos(angle), 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        )
    }

    nonisolated static func makeScale(_ scale: SIMD3<Float>) -> float4x4 {
        float4x4(
            [scale.x, 0, 0, 0],
            [0, scale.y, 0, 0],
            [0, 0, scale.z, 0],
            [0, 0, 0, 1]
        )
    }

    nonisolated static func lookAt(eye: SIMD3<Float>,
                                   target: SIMD3<Float>,
                                   up: SIMD3<Float>) -> float4x4 {
        let epsilon: Float = 0.000001
        let epsilonSquared = epsilon * epsilon

        // 1. Calculate forward vector (z-axis)
        let forward = target - eye
        guard length_squared(forward) > epsilonSquared else {
            return matrix_identity_float4x4
        }
        let zVector = normalize(forward)

        // 2. Calculate right vector (x-axis)
        var resolvedUp = length_squared(up) > epsilonSquared ? normalize(up) : SIMD3<Float>(0, 1, 0)
        var right = cross(resolvedUp, zVector)
        if length_squared(right) <= epsilonSquared {
            resolvedUp = abs(zVector.y) < 0.999 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(0, 0, 1)
            right = cross(resolvedUp, zVector)
        }
        let xVector = normalize(right) // Perpendicular to up and z

        // 3. Recalculate true up vector (y-axis)
        let yVector = cross(zVector, xVector)             // Guaranteed perpendicular

        // 4. Build rotation matrix
        let rotation = float4x4(
            [xVector.x, yVector.x, zVector.x, 0],
            [xVector.y, yVector.y, zVector.y, 0],
            [xVector.z, yVector.z, zVector.z, 0],
            [0, 0, 0, 1]
        )

        // 5. Add translation
        let translation = float4x4(
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [-eye.x, -eye.y, -eye.z, 1]
        )

        return rotation * translation
    }

    nonisolated static func perspective(fov: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let yValue = 1 / tan(fov * 0.5)
        let xValue = yValue / aspect
        let zValue = far / (far - near)
        let wValue = -far * near / (far - near)

        // Metal's clip space uses a top-left origin in screen space, which makes
        // the Y axis appear inverted compared to the typical mathematical
        // coordinate system. Negate the Y component so that positive Y points
        // upward on screen.
        return float4x4(
            [xValue, 0, 0, 0],
            [0, -yValue, 0, 0],
            [0, 0, zValue, 1],  // ← Should be 1 in 4th column
            [0, 0, wValue, 0]   // ← Should be 0 in 4th column
        )
    }
}
