//
//  MatrixExtensions.swift
//  OptiUniverse
//
//  Created by max on 24.07.2025.
//

import simd

extension float4x4 {
    static func makeTranslation(_ t: SIMD3<Float>) -> float4x4 {
        .init(
            [1, 0, 0, 0],
            [0, 1, 0, 0],
            [0, 0, 1, 0],
            [t.x, t.y, t.z, 1]
        )
    }
    
    static func makeRotationX(_ angle: Float) -> float4x4 {
        .init(
            [1, 0, 0, 0],
            [0, cos(angle), -sin(angle), 0],
            [0, sin(angle), cos(angle), 0],
            [0, 0, 0, 1]
        )
    }
    
    static func makeRotationY(_ angle: Float) -> float4x4 {
        .init(
            [cos(angle), 0, -sin(angle), 0],
            [0, 1, 0, 0],
            [sin(angle), 0, cos(angle), 0],
            [0, 0, 0, 1]
        )
    }
    
    static func makeRotationZ(_ angle: Float) -> float4x4 {
        .init(
            [cos(angle), sin(angle), 0, 0],
            [-sin(angle), cos(angle), 0, 0],
            [0, 0, 1, 0],
            [0, 0, 0, 1]
        )
    }
    
    static func makeScale(_ s: SIMD3<Float>) -> float4x4 {
        float4x4(
            [s.x, 0,   0,   0],
            [0,   s.y, 0,   0],
            [0,   0,   s.z, 0],
            [0,   0,   0,   1]
        )
    }
    
    static func lookAt(eye: SIMD3<Float>,
                       target: SIMD3<Float>,
                       up: SIMD3<Float>) -> float4x4 {
        let epsilon: Float = 0.000001
        
        // 1. Calculate forward vector (z-axis)
        let forward = target - eye
        guard length_squared(forward) > epsilon else {
            return matrix_identity_float4x4
        }
        let z = normalize(forward)
        
        // 2. Calculate right vector (x-axis)
        var resolvedUp = length_squared(up) > epsilon ? normalize(up) : SIMD3<Float>(0, 1, 0)
        var right = cross(resolvedUp, z)
        if length_squared(right) <= epsilon {
            resolvedUp = abs(z.y) < 0.999 ? SIMD3<Float>(0, 1, 0) : SIMD3<Float>(0, 0, 1)
            right = cross(resolvedUp, z)
        }
        let x = normalize(right) // Perpendicular to up and z
        
        // 3. Recalculate true up vector (y-axis)
        let y = cross(z, x)             // Guaranteed perpendicular
        
        // 4. Build rotation matrix
        let rotation = float4x4(
            [x.x, y.x, z.x, 0],
            [x.y, y.y, z.y, 0],
            [x.z, y.z, z.z, 0],
            [0,   0,   0,   1]
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
    
    static func perspective(fov: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let y = 1 / tan(fov * 0.5)
        let x = y / aspect
        let z = far / (far - near)
        let w = -far * near / (far - near)
        
        // Metal's clip space uses a top-left origin in screen space, which makes
        // the Y axis appear inverted compared to the typical mathematical
        // coordinate system. Negate the Y component so that positive Y points
        // upward on screen.
        return float4x4(
            [x,  0,  0,  0],
            [0, -y,  0,  0],
            [0,  0,  z,  1],  // ← Should be 1 in 4th column
            [0,  0,  w,  0]   // ← Should be 0 in 4th column
        )
    }
}
