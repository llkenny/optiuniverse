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
        // Forward vector from the eye toward the target
        let f = normalize(target - eye)
        // Right vector orthogonal to the forward direction
        let s = normalize(cross(f, up))
        // Recomputed up vector to ensure orthogonality
        let u = cross(s, f)

        // Build a column-major view matrix. Each `SIMD4` represents one column.
        // The translation components live in the final column so vertices are
        // correctly transformed relative to the camera position.
        return float4x4(
            SIMD4<Float>(s.x, s.y, s.z, 0),
            SIMD4<Float>(u.x, u.y, u.z, 0),
            SIMD4<Float>(-f.x, -f.y, -f.z, 0),
            SIMD4<Float>(-dot(s, eye), -dot(u, eye), dot(f, eye), 1)
        )
    }
    
    static func perspective(fov: Float, aspect: Float, near: Float, far: Float) -> float4x4 {
        let y = 1 / tan(fov * 0.5)
        let x = y / aspect
        let z = far / (far - near)
        let w = -far * near / (far - near)
        
        // Metal's clip space uses a right-handed system with Y pointing up.
        // The viewport transform converts to the top-left origin automatically,
        // so no Y inversion is necessary in this projection matrix.
        return float4x4(
            [x, 0, 0, 0],
            [0, y, 0, 0],
            [0, 0, z, 1],
            [0, 0, w, 0]
        )
    }
}
